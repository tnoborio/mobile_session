require 'rack'

class MobileSession < Rack::Session::Memcache
  def get_body(body, session_id)
    body.to_s.gsub(/<a +href=\"([^"]+)\">/) { "<a href=\"" + add_session_id($1, session_id) + "\">" }.
      gsub(/(<form.+>)/) { $1 + "<input type=\"hidden\" name=\"sid\" value=\"#{session_id}\">" }
  end

  def add_session_id(url, session_id)
    if /\?/ =~ url
      url + '&sid=' + session_id
    else
      url + '?sid=' + session_id
    end
  end

  def load_session(env)
    request = Rack::Request.new(env)
    session_id = request.GET['sid'] || request.POST['sid']
    begin
      session_id, session = get_session(env, session_id)
      env['rack.session'] = session
    rescue
      raise
      # env['rack.session'] = Hash.new
    end

    env['rack.session.options'] = @default_options.
      merge(:id => session_id)
  end
  
  def commit_session(env, status, headers, body)
    session = env['rack.session']
    options = env['rack.session.options']
    session_id = options[:id]
    
    if not session_id = set_session(env, session_id, session, options)
      env["rack.errors"].puts("Warning! #{self.class.name} failed to save session. Content dropped.")
      [status, headers, body]
    elsif options[:defer] and not options[:renew]
      env["rack.errors"].puts("Defering cookie for #{session_id}") if $VERBOSE
      [status, headers, body]
    else
      body_str = ""
      if body.respond_to? :to_str
        body_str << body.to_str
      elsif body.respond_to?(:each)
        body.each { |part|
          body_str << part.to_s
        }
      else
        raise TypeError, "stringable or iterable required"
      end
      
      if status == 302 and headers["Location"] and /sid=/ !~ headers["Location"]
        headers["Location"] = add_session_id(headers["Location"], session_id)
        return [status, headers, body_str]
        
      elsif status == 304
        return [status, headers, body_str]
      end

      body = get_body(body_str, session_id)
      headers['Content-Length'] = body.size.to_s
      
      [status, headers, body]
    end
  end
end
