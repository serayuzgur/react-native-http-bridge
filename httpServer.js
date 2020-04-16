/**
 * @providesModule react-native-http-server
 */
'use strict';

import { DeviceEventEmitter } from 'react-native';
import { NativeModules } from 'react-native';
var Server = NativeModules.HttpServer;

module.exports = {
    start: function (port, serviceName, callback, onStart) {
        if (port == 80) {
            throw "Invalid server port specified. Port 80 is reserved.";
        }

        if (onStart)
            DeviceEventEmitter.addListener('httpServerStarted', onStart);
        DeviceEventEmitter.addListener('httpServerResponseReceived', callback);

        Server.start(port, serviceName);
    },

    stop: function (onStop) {
        if (onStop)
            DeviceEventEmitter.addListener('httpServerStopped', onStop);
        Server.stop();
        DeviceEventEmitter.removeAllListeners('httpServerStarted');
        DeviceEventEmitter.removeAllListeners('httpServerStopped');
        DeviceEventEmitter.removeAllListeners('httpServerResponseReceived');
    },

    respond: function (requestId, code, type, body) {
        Server.respond(requestId, code, type, body);
    }
};
