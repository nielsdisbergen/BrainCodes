function MatlabTabToGit(varargin)

% @Niels R. Disbergen
% v0.2 - September 2016
%
% This function adds the currently open Matlab tab to a specified (GitHub)
% folder. The full directory depth is searched for a match and only if found
% and the timestamp is ahead of the existing file it will be copied. In case of
% no match in the destination folder, a save directory will be prompted.
% The desitnation path is hard-coded for convenience in destDir or can be
% provided as input.
% 
% Syntax:
%   - MatlabTabToGit()
%   - MatlabTabToGit('dest_path')
%
% Input:
%   'dest_path' = full path to destination folder
%


%% Assign and check variables

    narginchk(0,1)
    if nargin == 0
        destDir = '~\Codes';
    else
        destDir = varargin{1};
    end
    
    if exist(destDir,'dir') ~=7
        throw(MException('MatlabTabToGit:DirNotFound','Destination directory "%s" not found',destDir))
    end

%%
    % get current tab's dir and split filename
    currTabOpen = matlab.desktop.editor.getActiveFilename;
    [~,fName,fExt] = fileparts(currTabOpen);
    fCopyName = [fName fExt];

    % search all files in tree; using recursive call of GetAllFiles() to search full depth
    fileAllList = GetAllFiles(destDir);
    
    % if system-files or temporary Mat-files (*.m~), exclude from file list
    fileAllList = fileAllList(~strncmp(fileAllList, sprintf('%s%s.', destDir, filesep), length(destDir)+2));
    fileAllList = fileAllList(cellfun(@isempty, strfind(fileAllList, sprintf('%s~', fExt))));


%% Check if the to be copied file already exists somewhere in the destination dir

    % get file info, used to check for timestamp
    fileToGitInfo = dir(currTabOpen);

    % check full file list for occurance & store info on matches
    filesFound = {}; 
    fileNameMsg = {};
    cntFfound = 0;

    for cntFile=1:size(fileAllList,1)
        % check for full match and if no case-sensitive match is found, throw 
        % an error
        if ~isempty(strfind(fileAllList{cntFile}, fCopyName))
            cntFfound = cntFfound+1;
            filesFound{cntFfound} = fileAllList{cntFile};
            fileMatchInfo(cntFfound) = dir(filesFound{cntFfound});
            fileNameMsg{cntFfound} = sprintf('F%i: %s \n', cntFfound, filesFound{cntFfound});
            fileMatchNum(cntFfound,1) = cntFile;

        elseif ~isempty(strfind(lower(fileAllList{cntFile}), lower(fCopyName)))
            throw(MException('MatlabTabToGit:FileMatch:NonCaseSensitiveMatch', 'No case-sensitive match found, did find a non-case-sensitive one: \nFile: "%s" \nMatch: "%s"', fCopyName, fileAllList{cntFile}))

        end

    end


%% If file is matched create path name, if nont prompt, throw error when there are multiple matches

        nFileMatch = length(filesFound);
        newFile = false;
        
        if nFileMatch == 1 % single match
            gitSaveDir = fullfile(fileparts(filesFound{1}),fCopyName);

        elseif nFileMatch == 0 % no match
            fSavePath = uigetdir(destDir, sprintf('No file match found for "%s", please select save path', fCopyName));
            if fSavePath ~= 0
                gitSaveDir = fullfile(fSavePath, fCopyName);
                newFile = true;
            else
                throw(MException('MatlabTabToGit:FileMatch:DialogueCancel', ('Save dialogue cancelled, copying terminated')));
            end

        else % multiple matches
            msgbox(fileNameMsg,'Multiple instances of file found','warn')
            throw(MException('MatlabTabToGit:FileMatch:MultipleMatches', 'Multiple instances of file found (see message box), copying terminated'))

        end


%% If not a new file and timestamp is not ahead of existing file do not copy and print warning

    % if file already exists, check via timestamp if newer, same, or older
    if ~newFile
        gitMatchInfo = dir(gitSaveDir);
        
        if fileToGitInfo.datenum > gitMatchInfo.datenum
            tStampInf = 'newerTstamp';
        elseif fileToGitInfo.datenum == gitMatchInfo.datenum
            tStampInf = 'equalTstamp';
        elseif fileToGitInfo.datenum < gitMatchInfo.datenum
            tStampInf = 'destNewer';
        end

    % new file
    else 
        tStampInf = 'newFile';

    end    


    switch tStampInf
        % new file or current more recent
        case {'newFile' 'newerTstamp'}
            [statOut, statMsg] = copyfile(currTabOpen, gitSaveDir);

            if statOut
                sprintf('File "%s" sucessfully tranfered to "%s"', fCopyName, fileparts(gitSaveDir))
            else
                throw(MException('MatlabTabToGit:FileSave:TransferError', 'An error occured while transfering "%s" to "%s": \n%s', fCopyName, fileparts(gitSaveDir), statMsg));
            end

        % same file
        case 'equalTstamp'
            warning('File "%s" not copied, destination file has same timestamp:\n\tOrig: %s\n\tDest: %s', fCopyName, fileToGitInfo.date, fileMatchInfo(1).date)

        % destination is newer
        case 'destNewer'
            warning('File "%s" not copied, destination file timestamp is newer:\n\tOrig: %s\n\tDest: %s', fCopyName, fileToGitInfo.date, fileMatchInfo(1).date)

        % unknown
        otherwise
            throw(MException('MatlabTabToGit:FileSave:UnknownTimeStamp', 'Unknown time-stamp format detected: %s', tStampInf));

    end        


end
