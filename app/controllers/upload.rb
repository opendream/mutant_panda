class Uploader < Application
  def index
    render
  end

  def upload
    FileUtils.mv params[:file][:tempfile].path, MERB_ROOT+"/files/#{params[:file][:filename]}"
  end
end
