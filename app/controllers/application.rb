# all your other controllers should inherit from this one to share code.
class Application < Merb::Controller
  only_provides :json

private

  def authenticate_client
    raise Unauthorized unless Merb::Config[:clients].include? [params[:client], params[:api_key]]
  end
end  