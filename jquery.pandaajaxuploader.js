// This 2320 bytes for animated background color, so sad
(function(d){d.each(["backgroundColor","borderBottomColor","borderLeftColor","borderRightColor","borderTopColor","color","outlineColor"],function(f,e){d.fx.step[e]=function(g){if(!g.colorInit){g.start=c(g.elem,e);g.end=b(g.end);g.colorInit=true}g.elem.style[e]="rgb("+[Math.max(Math.min(parseInt((g.pos*(g.end[0]-g.start[0]))+g.start[0]),255),0),Math.max(Math.min(parseInt((g.pos*(g.end[1]-g.start[1]))+g.start[1]),255),0),Math.max(Math.min(parseInt((g.pos*(g.end[2]-g.start[2]))+g.start[2]),255),0)].join(",")+")"}});function b(f){var e;if(f&&f.constructor==Array&&f.length==3){return f}if(e=/rgb\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*\)/.exec(f)){return[parseInt(e[1]),parseInt(e[2]),parseInt(e[3])]}if(e=/rgb\(\s*([0-9]+(?:\.[0-9]+)?)\%\s*,\s*([0-9]+(?:\.[0-9]+)?)\%\s*,\s*([0-9]+(?:\.[0-9]+)?)\%\s*\)/.exec(f)){return[parseFloat(e[1])*2.55,parseFloat(e[2])*2.55,parseFloat(e[3])*2.55]}if(e=/#([a-fA-F0-9]{2})([a-fA-F0-9]{2})([a-fA-F0-9]{2})/.exec(f)){return[parseInt(e[1],16),parseInt(e[2],16),parseInt(e[3],16)]}if(e=/#([a-fA-F0-9])([a-fA-F0-9])([a-fA-F0-9])/.exec(f)){return[parseInt(e[1]+e[1],16),parseInt(e[2]+e[2],16),parseInt(e[3]+e[3],16)]}if(e=/rgba\(0, 0, 0, 0\)/.exec(f)){return a.transparent}return a[d.trim(f).toLowerCase()]}function c(g,e){var f;do{f=d.curCSS(g,e);if(f!=""&&f!="transparent"||d.nodeName(g,"body")){break}e="backgroundColor"}while(g=g.parentNode);return b(f)}var a={aqua:[0,255,255],azure:[240,255,255],beige:[245,245,220],black:[0,0,0],blue:[0,0,255],brown:[165,42,42],cyan:[0,255,255],darkblue:[0,0,139],darkcyan:[0,139,139],darkgrey:[169,169,169],darkgreen:[0,100,0],darkkhaki:[189,183,107],darkmagenta:[139,0,139],darkolivegreen:[85,107,47],darkorange:[255,140,0],darkorchid:[153,50,204],darkred:[139,0,0],darksalmon:[233,150,122],darkviolet:[148,0,211],fuchsia:[255,0,255],gold:[255,215,0],green:[0,128,0],indigo:[75,0,130],khaki:[240,230,140],lightblue:[173,216,230],lightcyan:[224,255,255],lightgreen:[144,238,144],lightgrey:[211,211,211],lightpink:[255,182,193],lightyellow:[255,255,224],lime:[0,255,0],magenta:[255,0,255],maroon:[128,0,0],navy:[0,0,128],olive:[128,128,0],orange:[255,165,0],pink:[255,192,203],purple:[128,0,128],violet:[128,0,128],red:[255,0,0],silver:[192,192,192],white:[255,255,255],yellow:[255,255,0],transparent:[255,255,255]}})(jQuery);

(function ($) {
  $.fn.extend({
    pandaAjaxUploader: function (options) {
      // Settings
      var defaults = {
        'server': 'http://localhost',
        'id': '',
        'interval': 1000,
        'path': './',
        'allowed_filetype': '*',
        'status_color': '#AAEE00',
        'error_color': '#EE6600',
        'upload_success': null
      };

      var options = $.extend(defaults, options);

      return this.each(function () {
        var server = options.server;
        var id = options.id;
        var interval = options.interval;
        var path = options.path;

        // Helper function to set animate progress bar.
        function barWidth(width) {
          $('#panda-progress-bar').stop().animate({width: width}, 400);
        }

        // Helper function to make status message.
        function statusSet(event, msg) {
          var status = $('#panda-progress-status');
          var oldBgColor = status.css('background-color');
          var nextColor;

          switch (event) {
            case 'status':
              nextColor = options.status_color;
              break;
            case 'error':
              nextColor = options.error_color;
              break;
            default:
              break;
          }

          status.html(msg);
          try {
            status
              .stop(false, true)
              .animate({backgroundColor: nextColor}, 400)
              .animate({backgroundColor: oldBgColor}, 400);
          } catch (err) {
            // Do nothing
          }
        }

        /**
         * Set state of form.
         */
        function state_set(state) {
          var form = $('#panda-ajax-uploader');
          var file = $('#panda-upload-file');
          var button = $('#panda-upload-button');
          var box = $('#panda-progress-box');
          var bar = $('#panda-progress-bar');
          var status = $('#panda-progress-status');

          $('#panda-progress-box').removeClass();
          switch (state) {
            case 'begin':
              file.show();
              button.attr('disabled', 'disabled').show();
              box.hide();
              var msg = '<p>Please choose a file to upload.</p>';
              if (options.allowed_filetype != '*') {
                msg += '<p>Allowed filetype are <em>' +
                       options.allowed_filetype.join(', ') +
                       '</em></p>';
              }

              statusSet('status', msg);
              break;
            case 'start_upload':
              file.hide();
              button.hide();
              box.show();
              statusSet('status', 'Uploading: 0%');
              break;
            case 'upload_success':
              clearInterval(window.pandaTimer);
              barWidth('100%');
              file.hide();
              button.hide();
              statusSet('status', 'Uploaded <em>' + $('#panda-upload-file').val() + '</em> success.');
              var filename = file.val();
              try {
                file.remove();
                options.upload_success(id, filename);
              }
              catch (err) {
                // Nothing
              }
              break;
            case 'upload_error':
              clearInterval(window.pandaTimer);
              state_set('begin');
              statusSet('error', 'Something error, Please try again.');
              break;
            default:
              break;
          }
        }

        // Fetch function
        function fetch() {
          $('#panda-progress-bar').animate({
            backgroundPosition: '+=10'
          }, interval);

          $.ajax({
            url: server + "/progress",
            dataType: 'jsonp',
            data: "X-Progress-ID=" + id,
            timeout: interval,
            success: function (upload) {
              var bar = $('#panda-progress-bar');
              var percent_success = 100 * (upload.received / upload.size);

              /* change the width */
              if (upload.state == 'uploading') {
                barWidth(percent_success + '%');
                $('#panda-progress-status').html('Uploading: ' + parseInt(percent_success) + '%');
              }
              /* we are done */
              if (upload.state == 'done') {
                state_set('upload_success');
              }
            },
            error: function (xhr) {
              state_set('upload_error');
            }
          });
        }

        // Make form.
        var form_str =
          '<form id="panda-ajax-uploader" target="panda-upload-iframe"' +
          '  action="' + server + '/upload/' + id + "?X-Progress-ID=" + id + '"' +
          '  method="POST" enctype="multipart/form-data">' +
          '  <input id="panda-upload-file" type="file" name="file" size="30" />' +
          '  <div id="panda-progress-box">' +
          '    <div id="panda-progress-bar">&nbsp;</div>' +
          '  </div>' +
          '  <div id="panda-progress-status">&nbsp;</div>' +
          '  <input type="submit" id="panda-upload-button" name="panda-upload-button" value="UPLOAD" />' +
          '</form>' +
          '<iframe id="panda-upload-iframe" name="panda-upload-iframe" width="0" height="0" frameborder="0" border="0" src="about:blank"></iframe>';
        $(this).prepend(form_str);

        state_set('begin');

        // Set progress fetching interval
        $('#panda-upload-button').click(function (e) {
          if (!$('#panda-upload-file').val()) {
            e.preventDefault();
            statusSet('Error', 'You must select a file.');
            return false;
          }
          state_set('start_upload');
          window.pandaTimer = setInterval(fetch, interval);
        });

        $('#panda-upload-file').change(function () {
          if (options.allowed_filetype != '*') {
            var filename = $(this).val();
            var ext = filename.split('.').pop().toLowerCase();
            if (jQuery.inArray(ext, options.allowed_filetype) == -1) {
              statusSet('error', '<p>Invalid filetype.</p>' +
                                 '<p>Allowed filetype are <em>' +
                                 options.allowed_filetype.join(', ') +
                                 '</em></p>');
              $('#panda-upload-button').attr('disabled', 'disabled');
              return $(this);
            }
          }
          statusSet('status', '<p>File <em>' + $(this).val() + '</em> selected.</p><p>You can change the file or click UPLOAD button to start uploading</p>');
          $('#panda-upload-button').removeAttr('disabled');
        });
      });
    }
  });
})(jQuery);
