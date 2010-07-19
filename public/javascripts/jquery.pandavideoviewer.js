(function ($) {
  $.fn.extend({
    pandaVideoViewer: function (options) {
      var defaults = {
        basePath: '',
        id: '',
        playlist: [],
        playerPath: 'http://203.151.20.184/flowplayer/flowplayer.swf',
        player: 'flowplayer',
        flowplayerControlPath: 'http://203.151.20.184/flowplayer/flowplayer.controls.swf',
        flowplayerPseudoStreamingPath: 'http://203.151.20.184/flowplayer/flowplayer.pseudostreaming-3.2.2.swf'
      }

      var options = $.extend(defaults, options);
      return this.each(function () {
        $(this).each(function () {
          // Inject streaming with nginx
          for (i in options.playlist) {
            options.playlist[i].provider = 'nginx'
          }
          // Initiate flowplayer
          var fp = flowplayer($(this).attr('id'), options.playerPath, {

            clip: {
              baseUrl: options.basePath,
              autoPlay: false,
              scaling: 'orig',
              provider: 'nginx'
            },

            playlist: options.playlist, 
            plugins: {
              controls: {
                //url: options.flowplayerControlPath
                "marginBottom":"0px","borderRadius":"0px","timeColor":"#ffffff","bufferGradient":"none","slowForward":true,"backgroundColor":"rgba(0, 0, 0, 0.6)","volumeSliderGradient":"none","slowBackward":false,"timeBorderRadius":20,"progressGradient":"none","time":true,"height":26,"volumeColor":"#4599ff","tooltips":{"stop":"Stop","slowMotionFBwd":"Fast backward","previous":"Previous","next":"Next","play":"Play","buttons":true,"slowMotionFwd":"Slow forward","unmute":"Unmute","pause":"Pause","fullscreen":"Fullscreen","slowMotionFFwd":"Fast forward","marginBottom":5,"fullscreenExit":"Exit fullscreen","volume":true,"scrubber":true,"slowMotionBwd":"Slow backward","mute":"Mute"},"fastBackward":false,"opacity":1,"timeFontSize":12,"bufferColor":"#a3a3a3","volumeSliderColor":"#ffffff","border":"0px","buttonColor":"#ffffff","mute":true,"autoHide":{"enabled":true,"hideDelay":500,"hideStyle":"fade","mouseOutDelay":500,"hideDuration":400,"fullscreenOnly":false},"backgroundGradient":"none","width":"100pct","display":"block","sliderBorder":"1px solid rgba(128, 128, 128, 0.7)","buttonOverColor":"#ffffff","fullscreen":true,"timeBgColor":"rgb(0, 0, 0, 0)","scrubberBarHeightRatio":0.2,"bottom":0,"stop":false,"zIndex":1,"sliderColor":"#000000","scrubberHeightRatio":0.6,"tooltipTextColor":"#ffffff","sliderGradient":"none","timeBgHeightRatio":0.8,"volumeSliderHeightRatio":0.6,"timeSeparator":" ","name":"controls","volumeBarHeightRatio":0.2,"left":"50pct","tooltipColor":"rgba(255, 0, 102, 1)","playlist":false,"top":328,"durationColor":"#b8d9ff","play":true,"fastForward":true,"progressColor":"#4599ff","timeBorder":"0px solid rgba(0, 0, 0, 0.3)","scrubber":true,"volume":true,"volumeBorder":"1px solid rgba(128, 128, 128, 0.7)","builtIn":false
              },
              nginx: {
                url: options.flowplayerPseudoStreamingPath
              }
            },

            debug: false
          });

          // Make options control
          // disabled
          /*
          var control = '<div id="for-' + $(this).attr('id') + '" class="panda-control-wrapper">' +
                        '  <div class="panda-size-control">' +
                        '    <span class="panda-size-sd">SD</span>' +
                        '    <span class="panda-size-hd">HD</span>' + 
                        '  </div>' +
                        '</div>';
          $(this).append(control);

          $('#for-' + $(this).attr('id') + ' .panda-size-sd').click(function() {
            var current_time = fp.getTime();
            fp.play(1)
            fp.seek(current_time);
          });

          $('#for-' + $(this).attr('id') + ' .panda-size-hd').click(function() {
            var current_time = fp.getTime();
            fp.play(2);
          });
          */
        });
      });
    }
  });
})(jQuery);
