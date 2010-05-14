class Image < Asset

  property :width, Integer
  property :height, Integer
  property :derived_assets, Json

  # typically reimplemented in subclasses
  def self.accepts_file?(tmp_file, mimetype)
    accepted_mimetypes.include? mimetype
  end

  # re-implemented
  def initial_processing
    skip_processing  # image assets are not processed (yet)
    send_to_store
  end

  # re-implemented
  def diverted_processing
    true
  end

  def self.accepted_mimetypes
    %w{image/bmp image/gif image/jpeg image/jpg image/tiff image/png}  # TODO check this with the features of the thumbnailer
  end

end
