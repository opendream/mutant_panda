class Exceptions < Application

  # response bodies contain json errors, except in development
  unless Merb::Config[:environment] == "development"
    def unauthorized;            json_error Unauthorized; end  # 401
    def forbidden;               json_error Forbidden; end  # 403
    def not_found;               json_error NotFound; end  # 404
    def not_acceptable;          json_error NotAcceptable; end  # 406
    def unsupported_media_type;  json_error UnsupportedMediaType; end  # 415
    def expectation_failed;      json_error ExpectationFailed; end  # 417
    def internal_server_error;   json_error InternalServerError; end  # 500
  end

private
  # fancy json errors -- TODO: make this work with the jquery upload progressbar error dialog
  def json_error(klass)
    base = { :status => klass.status, :error => klass.to_s.split('::').last, :requested => request.uri, :parameters => params }
    if Merb::Config[:exception_details]
      base.merge!({ :exceptions => request.exceptions.map{|e| {:message => e.message, :backtrace => safe_backtrace(e)}}})
    else  # do not throw pull stack traces of the line in production
      base.merge!({ :exceptions => request.exceptions.map{|e| {:message => e.message, :backtrace => safe_backtrace(e).first.to_a}}})
    end
    base.to_json
  end

  # do not show local paths to anyone
  def safe_backtrace(e)
    b = e.backtrace
    b.each { |i| i = i.gsub(Merb.root,'').split('/lib').last }
    b
  end
end