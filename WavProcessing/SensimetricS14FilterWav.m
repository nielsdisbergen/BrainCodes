function SensimetricS14FilterWav(wavFilePath, filtLeft, filtRight, varargin)
%
% @Niels R. Disbergen - 22 May 2014
%
% This function filters all wav-files on the wavFilePath with the
% Sensimetrics EQfiltering Matlab utility 'load_filter' and outputs filtered
% files. Filters are declared individually for each channel. If 1-channel
% wav-files are input, channel one is copied to two in order to perform
% channel-independent filtering. Wav-file naming can be adjusted by including a
% suffix labSuffix, the save-path can be changed from the loading path via
% savePath, and instead of processing all files at wavFilePath a file-list can
% be provided with their full path(s) via fileList.
%
% Input:
%   Required:
%     wavFilePath = filter all files on wavFilePath, save them at wavFilePath (dir)
%     filtLeft = individual left-channel filter (*.bin; Sensimetrics; dir)
%     filtRight = individual right-channel filter (*.bin; Sensimetrics; dir)
%
%   Optional:
%     labSuffix = add to end of file-name when saving for identification (str)
%     savePath = if declared save files at savePath instead of wavFilePath (dir)
%     fileList = process only the files included in this list, ignore wavFilePath (cell-dir)
%
% Syntax:
%   SensimetricS14FilterWav(wavFilePath, filtLeft, filtRight)
%   SensimetricS14FilterWav(wavFilePath, filtLeft, filtRight, labSuffix)
%   SensimetricS14FilterWav(wavFilePath, filtLeft, filtRight, labSuffix, savePath)
%   SensimetricS14FilterWav(wavFilePath, filtLeft, filtRight, labSuffix, savePath, fileList)
%

%% Parse input

    narginchk(3,5)

    pObj = inputParser;
    pObj.CaseSensitive = true;
    pObj.KeepUnmatched = true;
    pObj.FunctionName = mfilename;

    % set required vars and checks
    varsReq = {'wavFilePath', 'filtLeft', 'filtRight'};
    valReq = {@(x) exist(x, 'dir') == 7 @(x) exist(x, 'file') == 2 @(x) exist(x, 'file') == 2};

    N_VARS_REQ = length(varsReq);
    for cntReq = 1:N_VARS_REQ
        addRequired(pObj, varsReq{cntReq}, valReq{cntReq})
    end

    % if not assigned, set optional
    addOptional(pObj,'labSuffix', '', @isstr);
    addOptional(pObj,'savePath', wavFilePath, @isstr);
    addOptional(pObj,'fileList', dir(fullfile(wavFilePath, '*.wav')), @iscelstr);

    parse(pObj, wavFilePath, filtLeft, filtRight, varargin{:})
    DatIn = pObj.Results;


%% Check if save-dir exists and load Sensimetrics filters

    if exist(DatIn.savePath, 'dir') ~= 7
        mkdir(DatIn.savePath)
    end

    fprintf('Using %s for Sensimetrics filtering \n', DatIn.filtLeft);

    [impRespL, fsL] = load_filter(DatIn.filtLeft);
    [impRespR, fsR] = load_filter(DatIn.filtRight);

    if fsL ~= fsR
        throw(MException('Error: SensimetricS14FilterWav:FiltersSampleRatesNotEqual', 'Channel filter sample rates are not equal L=%i R=%i', fsL, fsR));
    end

    if isempty(DatIn.fileList)
        throw(MException('SensimetricS14FilterWav:NoWavOnPath', 'Error: no wav-files were found on the path or fileList was empty\n'))
    end


%% Filter all wav-files

    for cntFile = 1:size(DatIn.fileList, 1)

        wavDat = [];
        wavOut = [];

        % full file path and name to save filtered
        currentFile = fullfile(wavFilePath, DatIn.fileList(cntFile).name); 
        saveName = fullfile(DatIn.savePath, sprintf('%s_SeFil%s.wav', DatIn.fileList(cntFile).name(1:end-4), DatIn.labSuffix));
        
        % load current wav & get file info
        [wavDat, fsW] = audioread(currentFile);
        WavInfo = audioinfo(currentFile);

        % check if sample rate of filter and current wav-file are equal
        if fsL ~= fsW || fsR ~= fsW
            throw(MException('SensimetricS14FilterWav:SampleRatesFilterWavNotEqual', 'Error: sample frequency of %s (%i) not equal to filter sample frequencies L=%i; R=%i', DatIn.fileList(cntFile).name, fsW, fsL, fsR));
        end

        % channel-dependent convultions with the respective filters
        switch WavInfo.NumChannels
            case 1
                wavOut(:,1) = conv(impRespL, wavDat(:,1));
                wavOut(:,2) = conv(impRespR, wavDat(:,1));
                warning('FILECHANGE: input wav-file %s was one channel, channel 1 copied to 2 for channel-independent filtering', DatIn.fileList(cntFile).name)
            case 2
                wavOut(:,1) = conv(impRespL, wavDat(:,1));
                wavOut(:,2) = conv(impRespR, wavDat(:,2));
            otherwise
              throw(MException('SensimetricS14FilterWav:NumberOfChannelsOutsideOfImplementation', 'Error: wav-file has %i channels, function designed for 1 or 2 channel files only', WavInfo.NumChannels));
        end

        % Check if data is not clipping and attempt to correct when needed, write files
        corrWav = CheckClippWav(wavOut, DatIn.fileList(cntFile).name);
        audiowrite(saveName, corrWav, fsW, 'BitsPerSample', WavInfo.BitsPerSample);

    end

    if ~noFiles 
        fprintf('Finished filtering all wav-files\n')
    end

