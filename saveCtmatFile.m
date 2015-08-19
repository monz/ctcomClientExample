function [ ratedCtmatPath, newCounter ] = saveCtmatFile( ctData, ctmatDstDir, counter )
%CREATECTMATFILE Summary of this function goes here
%   Detailed explanation goes here

    % create new filename
    newCounter = counter + 2;
    filename = sprintf('chh %05i_kt3.i01', newCounter);
    ratedCtmatPath = [ctmatDstDir, filename, '.ctmat'];
    
    % save ctmat file into network share
    save(ratedCtmatPath, 'ctData');
    
end

