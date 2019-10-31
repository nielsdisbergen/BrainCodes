function RampWavFiles(filePath, timeRamp, varargin)

%
% @Niels R. Disbergen - February 2014
%
% This function applies log-ramping of length timeRamp to the beginning 
% and end of all wav-files at 'filePath'. If needed, clipping correction is 
% apllied. When clipping correction is not successfull an error will be thrown
% and the file not written. Otherwise the file(s) will be saved; saving 
% location depends on input.
%
% Syntax:
%   RampWavFiles('filePath', timeRamp)
%   RampWavFiles('filePath', timeRamp, 'savePath')
%
% Input:
%   filePath = ramp all files in filePath and save amplitude modulated  
%               files at 'filePath\AM\'.
%   timeRamp = ramp files over n-seconds (e.g. 0.1)
%   savePath = if declared, files saved at 'savePath\AM' instead
%

%% check and assign variables

    narginchk(2,3)

    if exist(filePath, 'dir') ~= 7
        throw(MException('RampWavFiles:FilePathNotExist', 'Path to files does not exist: "%s"', filePath));
    end

    filelist = dir(fullfile(filePath, '*.wav')); % get all wav-files on path

    if nargin == 2
        savePath = fullfile(filePath, 'AM');
    elseif nargin == 3
        savePath = fullfile(varargin{1}, 'AM');
    end

    if exist(savePath,'dir') ~= 7
        mkdir(savePath)
    end


%% create ramping curves, apply, and save wav-files
    
    for cntFile = 1:size(filelist, 1)

        wavDat = [];

        % read wav
        [wavDat, Fs] = audioread(fullfile(filePath, filelist(cntFile).name));
        wavSize = size(wavDat);

        samplesRamp = ceil(Fs * timeRamp); % n-points to ramp

        % error if file-length is less than the ramp times
        if wavSize(1,1) < samplesRamp*2
            throw(MException('RampWavFiles:FilePathNotExist', 'Ramp time of %1.2fs is longer than file length of %1.2fs', samplesRamp/Fs, wavSize(1,1)/Fs));
        end

        % set curve to ramp and correct infinite
        rampUpCurve = (exp(1/9) * log((0:samplesRamp-1) / timeRamp)) / max(abs(exp(1/9) * log((1:samplesRamp) / timeRamp)));
        rampUpCurve(abs(rampUpCurve) == inf) = 0;

        for cntChan = 1:wavSize(1,2)
            % ramp up
            wavDat(1:samplesRamp, cntChan) = wavDat(1:samplesRamp, cntChan) .* rampUpCurve';

            % ramp down
            wavDat(end-(samplesRamp-1):end, cntChan) = wavDat(end-(samplesRamp-1):end, cntChan) .* rampUpCurve(end:-1:1)';
        end

        % check for and correct clipping, save ramped wav
        [wavDat] = CheckClippWav(wavDat, filelist(cntFile).name);
        audiowrite(fullfile(savePath, sprintf('%s_AM.wav', filelist(cntFile).name(1:end-4))), wavDat, Fs)

    end

    fprintf('Finished ramping wav-files\n')

