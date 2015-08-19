clear all;
clc;


import ctcom.messageTypes.*;
import ctcom.messageImpl.*;
import ctcom.CtcomClient;

%% configuration 

ctmatDstDir = './';
ctmatShareDir = '/mnt/linuxdata/tmp/ctmatfiles/';
% host = '192.168.2.106';
host = 'localhost';
port = 4745;

algorithm = 'mockup';
fixedResult = 'niO';

dataStructFields = {'header', 'channelInfo', 'xAxisInfo', 'partInfo', ...
    'parts.engineInputs', 'parts.engineOutputs', 'windows', 'warnings'};

counter = 0;
%%

disp('Starting CTCOM client');

try
    client = CtcomClient(host, port);

    % prepare connection request
    request = ConnectMessage();
    % fill connect message
    for n = 1:length(dataStructFields)
        request.addToTestbenchRead(dataStructFields{n});
        request.addToTestbenchWrite(dataStructFields{n});
    end
    % send connection request
    client.sendConnectionRequest(request)
    % receive connection request acknowledgement message
    ack = client.getMessage();
    % check if received message is valid
    if isempty(ack)
        % TODO: close TCP connection
        error('Received message was invalid');
    elseif ack.getType() == MessageType.CONNECT
        % check if protcol version matches
        localProtocolVersion = request.getProtocolVersion();
        remoteProtocolVersion = ack.getProtocolVersion();
        if ~ isequal(localProtocolVersion, remoteProtocolVersion)
            fprintf('Protocol versions did not match, local: %s remote: %s', ...
                localProtocolVersion, remoteProtocolVersion);
        end
        % connection established, wait for the server to send readData
        % message
        while true
            message = client.getMessage();
            % check if received message is valid
            if isempty(message)
                disp('Received message was invalid');
                continue;
            elseif message.getType() == MessageType.READ_DATA
                % get file location from network share
                ctmatSource = char(message.getLocation());
                % load received new data
                [~,filename,ext] = fileparts(ctmatSource);
                ctmatData = load(ctmatSource,'-mat');
                % rate received ctmat data
                ratedCtmatData = rateCtmatData(ctmatData.ctData, algorithm, fixedResult);
                % save new ctmat data to network share
                [ratedCtmatPath, counter] = saveCtmatFile(ratedCtmatData, ctmatShareDir, counter);
                % return updated ctmat file
                returnMessage = ReadDataMessage();
                returnMessage.setLocation(ratedCtmatPath);
                client.sendMessage(returnMessage);
                
            elseif message.getType() == MessageType.QUIT
                fprintf('Quit: %s \n', char(message.getMessage()));
                break;
            end
        end
    end
catch ME
    disp(ME.message)
    try
        client.quit('shit happens');
    catch ME
        disp(ME.message)
    end
end
% end client
disp('Ending CTCOM Client');