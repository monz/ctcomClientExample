function printData( ctmatData )
%PRINTDATA Summary of this function goes here
%   Detailed explanation goes here

    disp('Header Info');
    fprintf('-- Fileformat %s\n', ctmatData.header.fileformat);
    fprintf('-- Engine number %s\n', ctmatData.header.engineNumber);

end

