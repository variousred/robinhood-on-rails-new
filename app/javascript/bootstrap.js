jQuery(function() {
  console.log("jQuery(function() {...}) for popover and tooltip")
  $("a[rel~=popover], .has-popover").popover();
  $("a[rel~=tooltip], .has-tooltip").tooltip();
});
