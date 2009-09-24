class Generic < Asset

  # typically reimplemented in subclasses
  # used to cast the asset to its specific type in the recast! method
  def self.accepts_file?(tmp_file, mimetype)
    true  # the generic asset class accepts all files (that have not been blacklisted in Asset)
  end

  # re-implemented
  def initial_processing
    skip_processing  # generic assets are not processed (yet)
    send_to_store
  end

  # re-implemented
  def diverted_processing
    true
  end

end