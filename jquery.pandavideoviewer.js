// Embed plugin
(function(){function a(b,c){if(b.substring(0,4)=="http"){return b}if(c){return c+(c.substring(c.length-1)!="/"?"/":"")+b}c=location.protocol+"//"+location.host;if(b.substring(0,1)=="/"){return c+b}var d=location.pathname;d=d.substring(0,d.lastIndexOf("/"));return c+d+"/"+b}$f.addPlugin("embed",function(d){var b=this;var c=b.getConfig(true);var e={width:b.getParent().clientWidth||"100%",height:b.getParent().clientHeight||"100%",url:a(b.getFlashParams().src),index:-1,allowfullscreen:true,allowscriptaccess:"always",id:"_"+b.id()};$f.extend(e,d);e.src=e.url;e.w3c=true;delete c.playerId;delete e.url;delete e.index;this.getEmbedCode=function(h,f){f=typeof f=="number"?f:e.index;if(f>=0){c.playlist=[b.getPlaylist()[f]]}f=0;$f.each(c.playlist,function(){c.playlist[f++].url=a(this.url,this.baseUrl)});var g=flashembed.getHTML(e,{config:c});if(!h){g=g.replace(/\</g,"&lt;").replace(/\>/g,"&gt;")}return g};return b})})();

(function ($) {
  $.fn.extend({
    pandaVideoViewer: function (options) {
      var defaults = {
        basePath: '',
        id: '',
        playlist: [],
        playerPath: 'http://10.0.1.216:4001/store/flowplayer/flowplayer.swf',
        player: 'flowplayer',
        flowplayerControlPath: 'http://10.0.1.216:4001/store/flowplayer/flowplayer.controls.swf',
        flowplayerPseudoStreamingPath: 'http://10.0.1.216:4001/store/flowplayer/flowplayer.pseudostreaming-3.2.2.swf'
      }

      var options = $.extend(defaults, options);
      return this.each(function () {
        $(this).each(function () {
          // Inject streaming with nginx
          /*
          for (i in options.playlist) {
            options.playlist[i].provider = 'nginx'
          }
          */
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
              },
              nginx: {
                url: options.flowplayerPseudoStreamingPath
              }
            },

            debug: false
          }).embed();

          var embedLink = $('<div id="' + $(this).attr('id') + '-embed-link" class="pandaviewer-embed-link"><a href="#">Show Embed Code</a></div>').insertAfter(this);
          $('<div id="' + $(this).attr('id') + '-embed-box" class="pandaviewer-embed-code">' + fp.getEmbedCode() + '</div>').insertAfter(embedLink);

          var embedBox = $('#' + $(this).attr('id') + '-embed-box').hide();
          $('#' + $(this).attr('id') + '-embed-link a').click(function (e) {
            e.preventDefault();
            embedBox.toggle();

            if ($(this).text() == 'Show Embed Code') {
              $(this).text('Hide Embed Code');
            }
            else {
              $(this).text('Show Embed Code');
            }
            
          });
        });
      });
    }
  });
})(jQuery);
