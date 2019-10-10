function [corrWav] = CheckClippWav(wavCheckDat, varargin)
%
% @Niels R. Disbergen - 30 July 2014
%
% This function checks for possible clipping in wav-files before data is
% used to write files. In case clipping is detected it tries to  correct by
% normalization and ONLY displays information when there was need for Correction.
% Code can be used on one and two channel data. Clipping correction is
% conservative to prevent issues in lower-spec systems or sound-cards which
% may already cause clips close to or at 1
%
% Input:
%   wavCheckDat = wav-data as output by audioread(), normalized
%   fileName = if displaying information regarding correction issues, also
%     include the file-name, for displaying purposes only
%
% Output:
%   corrWav = wav-file data, corrected for clipping when neeeded
%
% Syntax:
%   CheckClippWav(wavCheckDat)
%   CheckClippWav(wavCheckDat, fileName)
%

%% Assign & check variables

    narginchk(1,2)

    if nargin == 2
        fileName = varargin{1};

        if ~ischar(fileName)
            throw(MException('CheckClippWav:FileNameNotChar','Error: fileName is not a character array'));
        end

    else
        fileName = '';
    end


%% check if there is a clipping issue with the file

    clipIssue = 0;

    % process n-channel dependent
    switch size(wavCheckDat, 2)

        case 1 % 1-channel data
             % if any value is or exceeds 1
             if max(abs(wavCheckDat)) >= 1

                % get max values +.1 for normalization
                clipCorrAtt = (wavCheckDat / (max(abs(wavCheckDat)) + .1));

                % if correction not successful, flag
                if max(abs(clipCorrAtt)) >= 1
                    clipIssue = 2;
                else
                    clipIssue = 1;
                end
             end


        case 2 % 2-channel data
            % if any value is or exceeds 1
            if sum(max(abs(wavCheckDat))>=1) ~= 0

                % get max values +.1 for normalization
                corrChan1 = max(abs(wavCheckDat(:, 1))) + .1;
                corrChan2 = max(abs(wavCheckDat(:, 2))) + .1;

                if corrChan1 > corrChan2
                    clipCorrAtt = (wavCheckDat / corrChan1);
                else
                    clipCorrAtt = (wavCheckDat / corrChan2);
                end

                % if correction not successful, flag
                if sum(max(abs(clipCorrAtt))>=1) ~= 0
                    clipIssue = 2;
                else
                    clipIssue = 1;
                end
            end

        otherwise
            throw(MException('CheckClippWav:NumberOfChannelsOutsideOfImplementation', 'Error: n-channels in wav-file is %i, function written for 1 or 2 channel wav-files', size(wavCheckDat, 2)));
    end


%% Return wavData

    switch clipIssue
        % no issues
        case 0
            corrWav = wavCheckDat;

        % corrected
        case 1
            corrWav = clipCorrAtt;
            fprintf('*** Clipping-correction %s successful ***\n', fileName);

        % correction failed
        case 2
            throw(MException('CheckClippWav:ClipCorrectionFailed', 'Error: clipping correction failed "%s"', fileName));

        otherwise
            throw(MException('CheckClippWav:UnknownClipCorrectionError', 'Error: unknown issue during clipping correction'));

    end

end
