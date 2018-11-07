function getGrm(featname,inname) {
    grmDialog = window.open(featname, inname,"height=600, width=600, scrollbars=no, resizable=yes");
//    grmDialog = window.open(featname, inname,"scrollbars=no, resizable=yes");
    grmDialog.focus();
    return void(0);
};
function getSelectedTexts (select) {
  var r = new Array();
  for (var i = 0; i < select.options.length; i++)
    if (select.options[i].selected)
      r[r.length] = select.options[i].value;
  return r;
};
function collect(before, s, after) {
    sourceName = window.name;
    var re = /,/g;
    var outString = s; // s.replace(re,'-');
    outString = before + outString + after;
    if (window.opener && !window.opener.closed) 
	window.opener.document.reqForm.elements[sourceName].value += outString;
    window.returnValue = outString;
    window.close();
};
