class FileStore < AbstractStore
  include FileUtils
  
  def initialize
    raise RuntimeError, "You must specify store_dir and store_base_url" unless Merb::Config[:store_dir] && Merb::Config[:store_base_url]
    @dir = Merb::Config[:store_dir]
    mkdir_p(@dir)
  end
  
  # Set file. Returns true if success.
  def set(key, tmp_file)
    cp(tmp_file, @dir / key)
    true
  end
  
  # Get file.
  def get(key, tmp_file)
    cp(@dir / key, tmp_file)
  rescue
    Merb.logger.error "Tried to get #{key} from the store but the file does not exist"
    raise FileDoesNotExistError, "#{key} does not exist"
  end
  
  # Delete file. Returns true if success.
  def delete(key)
    rm(@dir / key)
  rescue
    Merb.logger.error "Tried to delete #{key} from the store but the file does not exist"
    raise FileDoesNotExistError, "#{key} does not exist"
  end
  
  # Return the publically accessible URL for the given key
  def url(key)
    %(http://#{Merb::Config[:store_base_url]}/#{key})
  end
end
