var http = require('http');
var uuid = require('node-uuid');

var sendInterval = 5000;

function sendServerSendEvent(req, res) {
  res.writeHead(200, {
    'Content-Type' : 'text/event-stream',
    'Cache-Control' : 'no-cache',
    'Connection' : 'keep-alive'
  });

  var sseID = uuid.v1();
  var data = "data payload"
  setInterval(function() {
    writeEvent(res, sseID, data);
  }, sendInterval);
}

function writeEvent(res, sseId, data) {
 res.write('id: ' + sseId + '\n');
 res.write('data: ' + data + '\n\n');
}

http.createServer(function(req, res) {
 if (req.headers.accept && req.headers.accept == 'text/event-stream' && req.url == '/sse'){
    sendServerSendEvent(req, res);
  }else{
    res.writeHead(404);
    res.end();
  }
}).listen(8080);