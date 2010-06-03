# merb -r "bin/queue_processor.rb"

Merb.logger.info 'Asset queue processor awake!'

loop do
  sleep (Merb::Config[:queue_processor_poll_frequency] or 5)
  Merb.logger.debug "Checking for jobs... #{Time.now}"
  if obj = Asset.next_job  # return a properly casted asset, or false
    begin
      obj.diverted_processing
    rescue => e
      begin
        # TODO do we want this error sender or merb-exceptions
        raise e
#        ErrorSender.log_and_email("encoding error", "Error encoding #{video.key}
#
##{$!}
#
#PARENT ATTRS
#
##{"="*60}\n#{video.parent_video.attributes.to_h.to_yaml}\n#{"="*60}
#
#ENCODING ATTRS
#
##{"="*60}\n#{video.attributes.to_h.to_yaml}\n#{"="*60}")
      rescue
        Merb.logger.error "Error sending error using ErrorSender.log_and_email - very erroneous! (#{$!})"
      end
    end
  end
end
