function [ ratedCtmatData ] = rateCtmatData( ctmatData, algorithm, fixedResult )
%RATECTMATDATA Summary of this function goes here
%   Detailed explanation goes here

    % rate values of ctmat data
    import SupportCodeML.*

    %% Run Test Algorithm on engine data
    algorithmParameters.algorithm = algorithm; % 'mockup'
    algorithmParameters.fixedResult = fixedResult; % 'iO', 'niO'
    ctDataOut = TestCtData(ctmatData, 'algorithmParameters', algorithmParameters);

    %% return rated results
    ratedCtmatData = ctDataOut;
    

end

