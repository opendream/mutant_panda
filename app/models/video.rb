class Video < Asset
  
  property :width, Integer
  property :height, Integer
  property :duration, Integer
  property :container, String
  property :video_codec, String
  property :video_bitrate, String
  property :fps, Integer
  property :audio_codec,String 
  property :audio_bitrate, String
  property :audio_sample_rate, String
  property :encoding_time, String
  property :encoded_at, String
  property :thumbnail_position, String
  property :derived_assets, Json

  class VideoError < AssetError; end
  class VideoFormatNotRecognized < VideoError; end
  class VideoInvalid < VideoError; end
  class VideoTooShort < VideoError; end

  # re-implemented
  def self.accepts_file?(tmp_file, mimetype)
    return false if Video.blacklisted_mimetypes.include? mimetype
    inspector = RVideo::Inspector.new(:file => tmp_file)
    return (inspector.valid? and inspector.video?)
  end

  # mimetype that we for sure cannot handle (we further accept files base on RVideo inspectors judgement)
  def self.blacklisted_mimetypes
    Image.accepted_mimetypes + %w{some/x-type other/x-type}  # blacklist all image types + more
  end

  # re-implemented from superclass
  def initial_processing
    self.pick_metadata
    self.queue_for_processing
    self.send_to_store
    self.save
  end

  # re-implemented from superclass
  def diverted_processing
    self.create_derived_assets
  end
  
  # delete an original video and all it's derived assets, then removes it from the db as well
  # re-implemented
  def obliterate!
    self.delete_derived_assets_from_store
    Store.delete(filename)
    self.destroy  # db
  rescue AbstractStore::FileDoesNotExistError
    false
  end

  # Reads information about the video into attributes.
  def pick_metadata
    Merb.logger.info "#{self.id}: Reading metadata of video file"
    
    inspector = RVideo::Inspector.new(:file => self.tmp_file_path)
    
    raise VideoFormatNotRecognized unless inspector.video?
    raise VideoInvalid unless inspector.valid?
    
    self.duration = (inspector.duration rescue nil)
    self.container = (inspector.container rescue nil)
    self.width = (inspector.width rescue nil)
    self.height = (inspector.height rescue nil)
    
    self.video_codec = (inspector.video_codec rescue nil)
    self.video_bitrate = (inspector.bitrate rescue nil)
    self.fps = (inspector.fps rescue nil)
    
    self.audio_codec = (inspector.audio_codec rescue nil)
    self.audio_sample_rate = (inspector.audio_sample_rate rescue nil)
    
    # Don't allow videos with a duration of 0
    raise VideoTooShort if self.duration == 0
  end

  
#   # API
#   # ===
#   
#   # Hash of paramenters for video and encodings when video.xml/yaml requested.
#   # 
#   # See the specs for an example of what this returns
#   # 
#   def show_response
# 
#     r = {
#       :video => {
#         :id => self.id,
#         :status => self.status
#       }
#     }
#     
#     # Common attributes for originals and encodings
#     if self.status == 'original' or self.encoding?
#       [:filename, :original_filename, :width, :height, :duration].each do |k|
#         r[:video][k] = self.send(k)
#       end
#       r[:video][:screenshot]  = self.clipping.filename(:screenshot)
#       r[:video][:thumbnail]   = self.clipping.filename(:thumbnail)
#     end
#     
#     # If the video is a parent, also return the data for all its encodings
#     if self.status == 'original'
#       r[:video][:encodings] = self.encodings.map {|e| e.show_response}
#     end
#     
#     # Reutrn extra attributes if the video is an encoding
#     if self.encoding?
#       r[:video].merge! \
#         [:parent, :profile, :profile_title, :encoded_at, :encoding_time].
#           map_to_hash { |k| {k => self.send(k)} }
#     end
#     
#     return r
#   end






  # Processing, transcoding, creating stills
  # ========================================

  # returns configured number of 'middle points', for example [25,50,75]
  def still_positions
    n = Merb::Config[:video_stills]
    return [50] unless n
    interval = 100.0 / (n + 1)  # interval length
    points = (0..(n + 1)).map { |p| p * interval }.map { |p| p.to_i }  # i.e.: [0,25,50,75,100] with n=3
    return points[1..-2]  # don't include the first and the last
  end
  
  def ffmpeg_resolution_and_padding(width, height)
    # Calculate resolution and any padding
    in_w = self.width.to_f
    in_h = self.height.to_f
    out_w = width.to_f
    out_h = height.to_f
    begin
      aspect = in_w / in_h
    rescue
      Merb.logger.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
      return %(-s #{width}x#{height})
    end
    height = (out_w / aspect.to_f).to_i
    height -= 1 if height % 2 == 1
    opts_string = %(-s #{width}x#{height} )
    if height > out_h  # crop top and bottom is the video is too tall
      crop = ((height.to_f - out_h) / 2.0).to_i
      crop -= 1 if crop % 2 == 1
      opts_string += %(-croptop #{crop} -cropbottom #{crop})
    elsif height < out_h  # add top and bottom bars if it's too wide (aspect wise)
      pad = ((out_h - height.to_f) / 2.0).to_i
      pad -= 1 if pad % 2 == 1
      opts_string += %(-padtop #{pad} -padbottom #{pad})
    end
    return opts_string
  end
  
  # calculate resolution and any padding for use with ffmpeg
  def ffmpeg_resolution_and_padding_no_cropping(width, height)
    in_w = self.width.to_f
    in_h = self.height.to_f
    out_w = width.to_f
    out_h = height.to_f
    begin
      aspect = in_w / in_h
      aspect_inv = in_h / in_w
    rescue
      Merb.logger.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
      return %(-s #{width}x#{height} )
    end
    height = (out_w / aspect.to_f).to_i
    height -= 1 if height % 2 == 1
    opts_string = %(-s #{width}x#{height} )
    if height > out_h  # keep the video's original width if the height
      width = (out_h / aspect_inv.to_f).to_i
      width -= 1 if width % 2 == 1
      opts_string = %(-s #{width}x#{height} )
    elsif height < out_h  # otherwise letterbox it
      pad = ((out_h - height.to_f) / 2.0).to_i
      pad -= 1 if pad % 2 == 1
      opts_string += %(-padtop #{pad} -padbottom #{pad})
    end
    return opts_string
  end

  # used by obliterate!() and create_derived_assets()
  def delete_derived_assets_from_store
    return false if derived_assets.blank? or not derived_assets.respond_to? :each_key
    derived_assets.each_key { |k| Store.delete(k) }
    self.derived_assets = nil
    save
  end
  
  # this method does the heavy lifting: transcoding and creating stills
  def create_derived_assets
    self.processing_started!  # change the state
    self.state = "processing"  # sometimes the previous line doesnt work, this makes sure it works TODO isolate and file this bug
    self.save
    begun_processing = Time.now
    Merb.logger.info "(#{begun_processing}) Processing #{id}"
    delete_derived_assets_from_store  # first delete all derived assets (if any)
    
    derived = {}  # this will keep info on the derived assets: { filename1 => { <info> }, filename2 => ... }
    begin
      fetch_from_store

      # start with transcoding the video according to the transcoding_profiles
      transcoder = RVideo::Transcoder.new
      Merb::Config[:transcoding_profiles].each_pair do |name, profile|
        recipe = transcoding_filename = ''
        if profile[:container] == "flv"
          Merb.logger.info "Encoding with encode_flv_flash"
          recipe = "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 24 $resolution_and_padding$ -y $output_file$"
          recipe += "\nflvtool2 -U $output_file$"
          transcoding_filename = "#{id}_#{name}.flv"
        elsif profile[:container] == "mp4" and profile[:audio_codec] == "aac"
          Merb.logger.info "Encoding with encode_mp4_aac_flash"
          recipe = "ffmpeg -i $input_file$ -acodec libfaac -ar 48000 -ab $audio_bitrate$k -ac 2 -b $video_bitrate_in_bits$ -vcodec libx264 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 24 -threads 4 -y $output_file$"
          transcoding_filename = "#{id}_#{name}.mp4"
        else  # try straight ffmpeg encode
          Merb.logger.info "Encoding with encode_unknown_format"
          recipe = "ffmpeg -i $input_file$ -f $container$ -vcodec $video_codec$ -b $video_bitrate_in_bits$ -ar $audio_sample_rate$ -ab $audio_bitrate$k -acodec $audio_codec$ -r 24 $resolution_and_padding$ -y $output_file$"
          transcoding_filename = "#{id}_#{name}.#{profile[:container]}"
        end
        transcoder.execute(recipe, recipe_options(profile, tmp_file_path, tmp_file_path(transcoding_filename)))
        derived[transcoding_filename] = { :type => 'transcoding', :recipe => recipe, :profile => profile, :transcoded_at => Time.now.to_json }
      end
      
      # create some stills for each transcoding
      transcoding_filenames = derived.keys
      transcoding_filenames.each do |tf|
        basename = tf[0..(-File.extname(tf).length-1)]  # remove extention
        still_positions.each do |position|
          still_filename = "#{basename}_#{position}.jpg"
          RVideo::FrameCapturer.capture!(:input => tmp_file_path(tf), :output => tmp_file_path(still_filename), :offset => "#{position}%")
          derived[still_filename] = { :type => 'still', :created_at => Time.now.to_json, :position => "#{position}%" }
        end
      end

      # put the derived assets in the store and delete the temporary files
      derived.each_key do |d|  # iterate over the derived assets' filenames
        Store.set(d, tmp_file_path(d))
        FileUtils.rm tmp_file_path(d)
      end
      FileUtils.rm tmp_file_path  # remove temporary local copy of the master video

      self.derived_assets = derived  # save the data of the derived assets
      self.processing_finished_at = Time.now
      self.processing_successful!
      self.start_sending_notification
      raise "Could not save asset '#{self.id}'" unless self.save
      
      processing_time = (Time.now - begun_processing).to_i
      Merb.logger.info "Successfully processed #{id} in #{processing_time} secs"
    rescue => e
      # remove derived without failing on errors
      begin
        FileUtils.rm tmp_file_path
        derived.each_key do |d|  # iterate over the derived assets' filenames
          begin
            FileUtils.rm tmp_file_path(d)
          rescue  # do not worrie about errors
          end
        end
      rescue  # do not worrie about errors
      end
      self.processing_failed
      self.start_sending_notification if not self.notification_url.blank?
      self.save
      Merb.logger.error "Processing of #{self.id} failed: #{$!.class} - #{$!.message}"
      raise e
    end
  end

  # basically merges: arguments, profile data and the return values of some method
  # returns a receipe as RVideo likes 'm
  def recipe_options(profile, input_file, output_file)
    {
      :input_file => input_file,
      :output_file => output_file,
      :container => profile[:container], 
      :video_codec => profile[:video_codec],
      :video_bitrate_in_bits => (profile[:video_bitrate] * 1024).to_s, 
      :fps => profile[:fps],
      :audio_codec => profile[:audio_codec],
      :audio_bitrate => profile[:audio_bitrate].to_s, 
      :audio_bitrate_in_bits => (profile[:audio_bitrate] * 1024).to_s, 
      :audio_sample_rate => profile[:audio_sample_rate].to_s,
      :resolution => "#{profile[:width]}x#{profile[:height]}",
      :resolution_and_padding => ffmpeg_resolution_and_padding_no_cropping(profile[:width], profile[:height])
    }
  end

end



# some more receipes:  (we use the panda defaults)

# recipe = "ffmpeg -i $input_file$ -ar 22050 -ab 48 -vcodec h264 -f mp4 -b #{video[:video_bitrate]} -r #{inspector.fps} -s" 
# recipe = "ffmpeg -i $input_file$ -ar 22050 -ab 48 -f flv -b $video_bitrate$ -r $fps$ -s"

# using -an to disable audio for now
# recipe = "ffmpeg -i $input_file$ -an -f flv -b $video_bitrate$ -s $resolution$ -y $output_file$" 

# Some crazy h264 stuff
# ffmpeg -y -i matrix.mov -v 1 -threads 1 -vcodec h264 -b 500 -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s 720x304 -acodec aac -ab 64 -ar 44100 -ac 1 -f mp4 -pass 1 matrix-h264.mp4

# ffmpeg -y -i matrix.mov -v 1 -threads 1 -vcodec h264 -b 500 -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s 720x304 -acodec aac -ab 64 -ar 44100 -ac 1 -f mp4 -pass 2 matrix-h264.mp4

# max_b_frames option not working, need to upgrade to ffmpeg svn. 
# See: http://lists.mplayerhq.hu/pipermail/ffmpeg-user/2006-September/004186.html
# recipe = "ffmpeg -y -i $input_file$ -v 1 -threads 1 -vcodec h264 -b $video_bitrate$ -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s $resolution$ -acodec aac -ab $audio_sample_rate$ -ar 44100 -ac 1 -f mp4 -pass 1 $output_file$"
# recipe += "ffmpeg -y -i $input_file$ -v 1 -threads 1 -vcodec h264 -b $video_bitrate$ -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s $resolution$ -acodec aac -ab $audio_sample_rate$ -ar 44100 -ac 1 -f mp4 -pass 2 $output_file$"

# recipe = "ffmpeg -i $input_file$ -an -vcodec libx264 -b $video_bitrate$ -bt $video_bitrate$ -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -s $resolution$ -y $output_file$"
# 2 pass encoding is slllloooowwwwwww
# recipe = "ffmpeg -y -i $input_file$ -an -pass 1 -vcodec libx264 -b $video_bitrate$ -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me umh -subq 5 -trellis 1 -refs 3 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -bt $video_bitrate$k -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.8 -qmin 10 -qmax 51 -qdiff 4 $output_file$"
# recipe += "\nffmpeg -y -i $input_file$ -an -pass 2 -vcodec libx264 -b $video_bitrate$ -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me umh -subq 5 -trellis 1 -refs 3 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -bt $video_bitrate$k -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.8 -qmin 10 -qmax 51 -qdiff 4 $output_file$"

