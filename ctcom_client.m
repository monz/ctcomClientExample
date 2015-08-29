function ctcom_client(configfile)
    import java.util.logging.Level;

    import ctcom.messageTypes.*;
    import ctcom.messageImpl.*;
    import ctcom.CtcomClient;
    import ctcom.util.LogHelper;

    %% configuration
    % TODO: validate xml config file with xsd schema
    
    ctcomConfig = ConfigReader.read(configfile, 'ctcom');
    host = ctcomConfig.server.ip;
    port = str2double(ctcomConfig.server.port);
    ctmatNetworkPath = fullfile(ctcomConfig.ctmatNetworkPath);
    readMsgTimeout = str2double(ctcomConfig.readMsgTimeout);

    loggingConfig = ConfigReader.read(configfile, 'logging');
    logfilePattern = loggingConfig.logfilePattern;
    append = strcmp('true', loggingConfig.appendLogfile);
    fileLoglevel = Level.parse(loggingConfig.loglevelFileLogging);
    consoleLoglevel = Level.parse(loggingConfig.loglevelConsoleLogging);

    algorithmConfig = ConfigReader.read(configfile, 'algorithm');
    algorithm = algorithmConfig.rateAlgorithm;
    fixedResult = algorithmConfig.fixedResult;

    % for this example implementation test bench read and write contain the
    % same values
    dataStructFields = ctcomConfig.testbenchRead;

    % static values
    counter = 0;
    
    %% prepare logger
    logHelper = LogHelper.getInstance();
    log = LogHelper.getLogger();
    log.info('preparing CTCOM client start');
    % set output file for logger
    if isempty(logHelper.getOutputFile) % have to check here, due to matlab weirdness, after script restart path ist still set
        log.config(sprintf('init logfile to "%s"', logfilePattern));
        logHelper.setOutputFile(logfilePattern, append);
    end
    % set file logger loglevel
    logHelper.setFileLoglevel(fileLoglevel);

    % set console logger loglevel
    logHelper.setConsoleLoglevel(consoleLoglevel);

    %% starting ctcom client
    log.info('Starting CTCOM client');
    disp('Starting CTCOM client');

    try
        log.info('Establish TCP connection to CTCOM server');
        client = CtcomClient(host, port);

        % prepare connection request
        request = ConnectMessage();
        % fill connect message
        for n = 1:length(dataStructFields)
            request.addToTestbenchRead(dataStructFields{n});
            request.addToTestbenchWrite(dataStructFields{n});
        end
        log.info('Send CTCOM connection message');
        % send connection request
        client.sendConnectionRequest(request)

        log.info('Receive CTCOM connection acknowledge message');
        % receive connection request acknowledgement message
        try
            ack = client.getMessage(readMsgTimeout);
        catch ME
            log.severe(sprintf('Reading CTCOM connection request acknowledgement message timed out: %s', ME.message));
            % close TCP connection
            client.close();
            return;
        end

        % check if received message is valid
        if isempty(ack)

            log.warning('Received CTCOM connection acknowledge message was invalid');
            % close TCP connection
            client.close();
            error('Received message was invalid');

        elseif ack.getType() == MessageType.CONNECT

            log.info('Successfully received CTCOM acknowledge message');
            log.info('Check if CTCOM protocol version matches');

            % check if protcol version matches
            localProtocolVersion = request.getProtocolVersion();
            remoteProtocolVersion = ack.getProtocolVersion();
            if ~ isequal(localProtocolVersion, remoteProtocolVersion)
                log.warning('CTCOM protocol version did not match');
                fprintf('Protocol versions did not match, local: %s remote: %s', ...
                    localProtocolVersion, remoteProtocolVersion);
                
                % receiving quit message from server
                try
                    message = client.getMessage(readMsgTimeout);
                catch ME
                    log.severe(sprintf('Reading CTCOM quit message timed out: %s', ME.message));
                    return;
                end
                
                if isempty(message)
                    return;
                elseif message.getType() == MessageType.QUIT
                    log.info(sprintf('Received CTCOM quit message "%s"', message.getMessage()));
                    disp(message.getMessage());
                end
                
                return;
            end

            % connection established, wait for the server to send readData
            % message, if protocol version did not match receive the quit
            % message from the ctcom server
            while true

                log.info('Receive next CTCOM message from the CTCOM server');
                try
                    message = client.getMessage(readMsgTimeout);
                catch ME
                    log.severe(sprintf('Reading CTCOM message string timed out: %s', ME.message));
                    quitMessage = QuitMessage();
                    quitMessage.setMessage('Closing connection due to read message timeout.');
                    client.sendMessage(quitMessage);
                    break;
                end

                % check if received message is valid
                if isempty(message)

                    log.warning('Received CTCOM message was invalid');
                    continue;

                elseif message.getType() == MessageType.READ_DATA

                    log.info('Received CTCOM readData message');
                    % get file location from network share
                    ctmatSource = char(message.getLocation());

                    log.info('Load CTMAT file from received location');
                    % load received new data
                    ctmatData = load(ctmatSource,'-mat');

                    log.info('Rate received ctmat data');
                    % rate received ctmat data
                    ratedCtmatData = rateCtmatData(ctmatData.ctData, algorithm, fixedResult);

                    log.info('Save rated ctmat data');
                    % save new ctmat data to network share
                    [ratedCtmatPath, counter] = saveCtmatFile(ratedCtmatData, ctmatNetworkPath, counter);

                    log.info('Send new CTCOM readData message to server, inform about new CTMAT file');
                    % return updated ctmat file
                    returnMessage = ReadDataMessage();
                    returnMessage.setLocation(ratedCtmatPath);
                    client.sendMessage(returnMessage);

                elseif message.getType() == MessageType.QUIT

                    log.info('Received CTCOM quit message');
                    fprintf('Quit: %s \n', char(message.getMessage()));
                    break;

                else
                    log.info('Received neither CTCOM readData nor quit message');
                    continue;
                end
            end
        end
    catch ME
        log.severe(sprintf('An error occurrred "%s"', ME.message));
        try
            if exist('client', 'var')
                log.info('Try to send CTCOM quit message to the CTCOM serve');
                client.quit('shit happens');
            end
        catch ME
            log.severe(sprintf('An error occurrred "%s"', ME.message));
        end
    end
    % end client
    log.info('Ending CTCOM client');
    disp('Ending CTCOM Client');
end