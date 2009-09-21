class Videos < Application
#   before :require_login, :only => [:index, :show, :destroy, :new, :create, :add_to_queue]
  before :set_video, :only => [:show, :destroy, :add_to_queue]
  before :set_video_with_nice_errors, :only => [:form, :done, :state]

  def index
    provides :json
    
    @videos = Video.all_originals
    display @videos
  end

  def show
    provides :json
    
    display @video.show_response
  end
  
  def destroy
    @video.obliterate!
    display true
  end

  def create
    provides :json
    
    @video = Video.create_empty
    Merb.logger.info "#{@video.key}: Created video"
    
    headers.merge!({'Location'=> "/videos/#{@video.key}"})
    display({:video => {:id => @video.id}})
  end
  
  # Flash us default option for upload (as it can be done as inline in a site). For larger files, http upload with the ajax progress bar can be used.
  def upload
    provides :html, :json
    begin
      @video = Video.get(params[:id])
      @video.initial_processing(params[:file])
    rescue DataMapper::ObjectNotFoundError
      # No empty video object exists
      self.status = 404
      render_error($!.to_s.gsub(/DataMapper::/,""))
    rescue Video::NotValid
      # Video object is not empty. Likely a video has already been uploaded.
      self.status = 404
      render_error($!.to_s.gsub(/Video::/,""))
    rescue Video::VideoError
      # Generic Video error
      self.status = 500
      render_error($!.to_s.gsub(/Video::/,""))
    rescue => e
      # Other error
      self.status = 500
      render_error("InternalServerError", e)
    else
      redirect_url = @video.upload_redirect_url
      render_then_call(iframe_params(:location => redirect_url)) do
        @video.finish_processing_and_queue_encodings
      end
    end
  end
  
  # Default upload_redirect_url (set in panda_init.rb) goes here.
  def done
    render :layout => :uploader
  end
  
private

  def render_error(msg, exception = nil)
    Merb.logger.error "#{params[:id]}: (500 returned to client) #{msg}" + (exception ? "#{exception}\n#{exception.backtrace.join("\n")}" : '')

    case content_type
    when :html
      if params[:iframe] == "true"
        iframe_params(:error => msg)
      else
        @exception = msg
        render(:template => "exceptions/video_exception", :layout => false) # TODO: Why is :action setting 404 instead of 500?!?!
      end
    when :json
      display({:error => msg})
    end
  end
  
  # Throws DataMapper::ObjectNotFoundError if video cannot be found
  def set_video
    @video = Video.get!(params[:id])
  rescue DataMapper::ObjectNotFoundError
    raise NotFound
  end
  
  def set_video_with_nice_errors
    begin
      @video = Video.get!(params[:id])
    rescue DataMapper::ObjectNotFoundError
      self.status = 404
      throw :halt, render_error($!.to_s.gsub(/DataMapper::/,""))
    end
  end
  
  # Textarea hack to get around the fact that the form is submitted with a 
  # hidden iframe and thus the response is rendered in the iframe.
  def iframe_params(options)
    "<textarea>" + options.to_json + "</textarea>"
  end
end
