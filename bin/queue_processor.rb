# merb -r "bin/queue_processor.rb"

Merb.logger.info 'Asset queue processor awake!'

loop do
  sleep (Merb::Config[:queue_processor_poll_frequency] or 5)
  Merb.logger.debug "Checking for jobs... #{Time.now}"
  if obj = Asset.next_job  # return a properly casted asset, or false
    #obj.diverted_processing
    begin
      obj.diverted_processing
    rescue => e
      Merb.logger.error "Error sending error using ErrorSender.log_and_email - very erroneous! (#{$!})"
    end
  end
end
