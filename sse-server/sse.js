var http = require('http');
var uuid = require('node-uuid');

var sendInterval = 3000;

var userNames = ["John", "Monica", "Martin", "Rose", "James", "Tom"];
var randomMessages = ["I'm fine", "I'll meet you in 10 minutes", "I'll call you back later", "I'm busy"];

var intervalID = null;

function sendServerSendEvent(req, res) {
  console.log("Connected")
  res.writeHead(200, {
    'Content-Type' : 'text/event-stream',
    'Cache-Control' : 'no-cache',
    'Connection' : 'keep-alive'
  });
  
  res.write('\n');

  intervalID = setInterval(function() {
    var eventId = uuid.v1();
    var eventName = null;
    var eventData = randomMessages[getRandom(0,randomMessages.length)]

    if (getRandom(0,2) == 0) {
      eventName = "user-connected";
      eventData = userNames[getRandom(0,userNames.length)]
    }

    console.log('id:    ' + eventId);
    console.log('event: ' + eventName);
    console.log('data:  ' + eventData + '\n');

    writeEvent(res, eventId , eventName, eventData);

  }, sendInterval);
}

function writeEvent(res, sseId, eventName, data) {
    var payload = ""

    payload = 'id: ' + sseId + '\n';

    if (eventName) {
      payload += 'event: ' + eventName + '\n'; 
    }

    payload += 'data: ' + data + '\n\n';

    res.write(payload);
}

function getRandom(min, max) {
  return Math.floor(Math.random() * (max - min) + min);
}

http.createServer(function(req, res) {
 if (req.headers.accept && req.headers.accept == 'text/event-stream' && req.url == '/sse'){

    req.on('close', function(){
        clearInterval(intervalID);
    });

    sendServerSendEvent(req, res);
  }else{
    res.writeHead(404);
    res.end();
  }
}).listen(8080);