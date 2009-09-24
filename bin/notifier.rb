# merb -r "panda/bin/notifier.rb"

# How notifications work, read this code:

Merb.logger.info 'Notifier awake!'

loop do
  sleep (Merb::Config[:notifier_poll_frequency] or 5)
  Merb.logger.debug "Checking for messages... #{Time.now}"
  Asset.outstanding_notifications.each do |asset|
    begin
      asset.send_notification if asset.time_to_send_notification?
    rescue
      Merb.logger.error "ERROR (#{$!.to_s}) sending notification for #{asset.id}. Waiting #{asset.notification_wait_period}s before trying again."
    end
    sleep 1
  end
end