// thanks darkdrgn2k for your help and support!
// src https://stackoverflow.com/questions/21789425/simple-xhr-long-polling-without-jquery

var xhr = new XMLHttpRequest()
xhr.responseType = 'text'//or 'text', 'json', ect. there are other types.
xhr.timeout = 60000//milliseconds until timeout fires. (1 minute)
xhr.onload = function() {
  content = xhr.responseText
  if(content != "not available") {
    //console.log('got it!')
    document.getElementsByClassName('loader')[0].style.display = "none"
    document.location = content
  }
  else {
    //console.log('tried if file is available')
    setTimeout("get_file()", 4000)
  }
}

xhr.ontimeout = function(){
  //if you get this you probably should try to make the connection again.
  //the browser should've killed the connection.
}

function get_file() {
  // visibility -> src https://stackoverflow.com/questions/42389937/trying-to-toggle-visibility-of-classes-with-buttons-using-javascript-absolute
  document.getElementsByClassName('loader')[0].style.display = "block"
  var notice = document.getElementById('notice').textContent
  var file_name = notice.split(':')[1].trim() + '.zip'
  var download_req = "/download?file=" + file_name
  xhr.open('GET', download_req, true)
  xhr.send()
}

// src src https://stackoverflow.com/questions/799981/document-ready-equivalent-without-jquery
document.addEventListener('DOMContentLoaded', function() {
   // TODO change test id (notice or what)
   var notice = document.getElementById('notice').textContent
   if ( notice.match('Petition received to build node') ) {
     get_file()
   }
})

