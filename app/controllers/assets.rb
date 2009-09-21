class Assets < Application
  before :authenticate_client, :exclude => ['form', 'upload']

  def info
    { :service => "mutant panda", :version => "0.1", :operated_by => "opendream" }.to_json
  end

  def form
    provides :html
    set_asset
    ensure_client_owns_asset
    "<form action='/upload/#{@asset.id}' method='post' enctype='multipart/form-data'><input type='file' name='file'/><input type='submit' value='Send'/></form>"
  end

  def new(client, success_url=nil, failure_url=nil)
    @asset = Asset.new
    @asset.client = client
    @asset.upload_success_redirect_url = success_url
    @asset.upload_failure_redirect_url = failure_url
    @asset.save
    Merb.logger.info "#{@asset.id}: Created asset"
    self.status = 201  # Created
    headers.merge!({'Location'=> "/assets/#{@asset.id}"})  # obey the http 1.1 spec
    @asset.id.to_json
  end

  def upload(id)
    # no need to check if client owns asset, since the asset id is unguessably secret...
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
      obj = @asset.recast!
      obj.process_payload  # should raise errors when it finds something inacceptable
      if obj.save
        redirect((obj.upload_success_redirect_url or raise Accepted))  # 202
      else
        raise NotAcceptable
      end
#     rescue
#       redirect((obj.upload_failure_redirect_url or raise NotAcceptable))  # 406
    end
  end

  def show
    set_asset
    ensure_client_owns_asset
    @asset.to_json
  end
  
  def delete
    set_asset
    ensure_client_owns_asset
    id = @asset.id
    @asset.destroy
    { 'deleted' => id }.to_json
  end
  
private

  def set_asset
    raise NotFound.new("Parameter 'id' is missing") unless params[:id]
    @asset = Asset.get_and_cast!(params[:id])  # can return an instance of an Asset subclass
  rescue DataMapper::ObjectNotFoundError
    raise NotFound.new("Could no find asset with id '#{params[:id]}'")
  end

  def ensure_client_owns_asset
    raise Unauthorized.new("This asset does not belong to you") unless @asset.client == params[:client]
  end
end
