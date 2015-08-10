clear all;
clc;


import ctcom.messageTypes.*;
import ctcom.messageImpl.*;
import ctcom.CtcomClient;

%% configuration 

ctmatDestination = './';
host = '192.168.2.106';
%host = 'localhost';
port = 4745;

%%

disp('Starting CTCOM client');

try
    client = CtcomClient(host, port);

    % prepare connection request
    request = ConnectMessage();
    request.addToTestbenchRead('header');
    request.addToTestbenchRead('partInfo');
    request.addToTestbenchWrite('header');
    request.addToTestbenchWrite('warnings');
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
            error(fprintf('Protocol versions did not match, local: %s remote: %s', ...
                localProtocolVersion, remoteProtocolVersion));
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
                % copy ctmat file from network share
                ctmatSource = char(message.getLocation());
                copyCtmat(ctmatSource, ctmatDestination)
                % load received new data
                [~,filename,ext] = fileparts(ctmatSource);
                ctmatFile = [ctmatDestination, filesep, filename, ext];
                ctmatData = load(ctmatFile,'-mat');
                % handle data
                % TODO: insert algorithm here
                printData(ctmatData.outCtmat);
                % return updated ctmat file
                returnMessage = ReadDataMessage();
                returnMessage.setLocation(message.getLocation());
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