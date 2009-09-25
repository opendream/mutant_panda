# all routes lead to assets... :)
# this is where all controller logic lives.
class Assets < Application
  only_provides :json
  before :authenticate_client, :exclude => ['upload']

  # be nice, give some info
  def info
    { :service => "mutant panda", :version => "0.1", :operated_by => "opendream" }.to_json
  end

  # should only be used for testing purpose -- undocumented in the RESTapi
  def form
    provides :html
    set_asset
    ensure_client_owns_asset

    # this is a simple (no progressbar) upload form:
    return "<form action='/upload/#{@asset.id}' method='post' enctype='multipart/form-data'><input type='file' name='file'/><input type='submit' value='Send'/></form>"

#     render :layout => 'uploader'  # this is a fancy upload mechanism (uses jquery+nginx plugins)
  end

  # create an empty asset, ready to be uploaded to
  def new(client, success_url=nil, failure_url=nil, notification_url=nil)
    @asset = Asset.new
    @asset.client = client
    @asset.upload_success_redirect_url = success_url
    @asset.upload_failure_redirect_url = failure_url
    @asset.notification_url = notification_url  # when nil no notification is sent
    @asset.save
    Merb.logger.info "#{@asset.id}: Created asset"
    self.status = 201  # Created
    headers.merge!({'Location'=> "/assets/#{@asset.id}"})  # obey the http 1.1 spec
    @asset.id.to_json
  end

  # this is where the file get uploaded to
  def upload(id)
    # no need to check if the client owns this asset, since the asset id is unguessably secret...
    begin
      @asset = Asset.get(id)  # before file is uploaded all assets are of base type Asset
      @asset.accept_upload(params[:file])
    rescue DataMapper::ObjectNotFoundError  # No empty video object exists
      raise NotFound  # 404
    rescue Asset::NoFileSubmitted
      raise ExpectationFailed  # 417
    rescue Asset::AssetNotEmpty
      raise Forbidden  # 403
    rescue Asset::MimeTypeBlacklisted
      raise UnsupportedMediaType  # 415
#     rescue => e
#       Merb.logger.error "#{params[:id]}: (500 returned to client) #{msg}" + (exception ? "#{exception}\n#{exception.backtrace.join("\n")}" : '')
#       raise InternalServerError  # 500
    end
    begin
      obj = @asset.recast!  # casts the asset to is proper type..
      obj.initial_processing  # should raise errors when it finds something inacceptable
      if obj.save
        redirect((obj.upload_success_redirect_url or raise Accepted.new(
          "No success_url has been supplied so you see this message")))  # 202
      else
        raise NotAcceptable.new("Could not save the asset")  # 406
      end
    rescue => e
      if obj
        redirect obj.upload_failure_redirect_url
      else
        raise e
      end
    end
  end

  # show the json representation of the asset
  def show
    set_asset
    ensure_client_owns_asset
    @asset.to_json
  end
  
  # delete the asset
  def delete
    set_asset
    ensure_client_owns_asset
    id = @asset.id
    @asset.obliterate!
    { 'deleted' => id }.to_json
  end
  

private

  # get the asset from the model casted to its most specific type
  def set_asset
    raise NotFound.new("Parameter 'id' is missing") unless params[:id]
    @asset = Asset.get_and_cast!(params[:id])  # can return an instance of an Asset subclass
  rescue DataMapper::ObjectNotFoundError
    raise NotFound.new("Could no find asset with id '#{params[:id]}'")
  end

  # make sure clients are not messing with eachothers assets.
  def ensure_client_owns_asset
    raise Unauthorized.new("This asset does not belong to you") unless @asset.client == params[:client]
  end

  # and our super **UNBREAKABLE**, $1000000, authentication system  :-)
  def authenticate_client
    raise Unauthorized unless Merb::Config[:clients].include? [params[:client], params[:api_key]]
  end
end
