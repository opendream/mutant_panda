class Image < Asset



  # typically reimplemented in subclasses
  def self.accepts_file?(tmp_file, mimetype)
    return true if accepted_mimetypes.include? mimetype
    false
  end

  # this is typically re-implemented in subclasses
  def process_payload
    skip_processing  # generic assets are not processed (yet)
    send_to_store
  end

  def self.accepted_mimetypes
    %w{image/bmp image/gif image/jpeg image/tiff image/png}
  end

end
