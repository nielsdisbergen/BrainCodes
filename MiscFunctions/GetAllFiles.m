function [dirFileList, varargout] = GetAllFiles(dirName, varargin)

% @Niels R. Disbergen - June 2015 - Extended August 2017
%
% This function recursively lists all files below it in the directory tree, 
% outputting them as strings in a cell array. It offers additional options to
% modify the dirs by trimming to filenames only, collapsing into a single new 
% dir, modify the directory base, and *.git files can be excluded.
%
% Syntax:
%   Find all files and ...
%       - their full directory tree:
%           dirList = GetAllFiles(dirName)
%
%       - trim to filenames only:
%           [dirList, fileNames] = GetAllFiles(dirName, true)
%
%       - collapse all into single new dir:
%           [dirList, fileDirNames] = GetAllFiles(dirName, true, newDir)
%
%       - change only their directory base:
%           [dirList, newDirBase] = GetAllFiles(dirName, false, newDir) 
%
%       - exclude *.git-files:
%           [dirList, newDirBase] = GetAllFiles(dirName, false, newDir, exclGitFiles) 
%
% Input:
%   dirName = directory to search (str)
%   collapseDirs = trim to filenames (logical)
%   newDir = new base-directory (str)
%   exclGitFiles = exclude *.git files (logical)
%

%% Assign and check input variables

    narginchk(1,4)
    
    % determine if filenames need to be trimmed or a new base dir is called
    if nargin >= 2
        
        % check if collapseDirs is logical
        if ~islogical(varargin{1})
            throw(MException('GetAllFiles:collapseDirsNotLogical', 'Variable collapseDirs is not a logical'))
        end
        
        newDirBase = false;
        
        if varargin{1}
            collapseDirs = true;

            if nargin >= 3
                newDir = varargin{2};
            else
                newDir = '';
            end

        else
            collapseDirs = false;

            if nargin >= 3
                newDirBase = true;
                newDir = varargin{2};
            else
                newDirBase = false;
            end
        end
        
    else
        collapseDirs = false;
        newDirBase = false;
    end
    
    % determine if git-files need to be excluded
    if nargin == 4 && varargin{3}
        gitExcl = true;
    else
        gitExcl = false;
    end


%%  Get all the directory files recursively

    dirData = dir(dirName); % directory structure
  
    dirIndex = [dirData.isdir]; % Logical index of all the sub-directories

    dirFileList = {dirData(~dirIndex).name}'; % Get files at current level

    % Add the path to the current files
    if ~isempty(dirFileList)
        dirFileList = cellfun(@(x) fullfile(dirName, x), dirFileList, 'UniformOutput', false);
    end

    subDirs = {dirData(dirIndex).name}; % List the subdir paths at current level

    if gitExcl
        for indGit = find(ismember(subDirs,{'.git'}))
            subDirs(indGit) = [];
        end
    end

    % Find all non-current and non-parent directories and loop over them recursively
    for indDir = find(~ismember(subDirs,{'.', '..'}))
        dirFileList = [dirFileList; GetAllFiles(fullfile(dirName, subDirs{indDir}))];
    end


%% Adjust/Collapse dirs (into new dir) if called

    % trim to filenames only
    if collapseDirs 
        nFiles = length(dirFileList);
        dirCollapse = cell(nFiles, 1);
        for cntFlist = 1:nFiles
            [~, fName, fExt] = fileparts(dirFileList{cntFlist});
            dirCollapse{cntFlist,1} = fullfile(newDir, [fName fExt]);
        end

        varargout{1} = dirCollapse;
        
    % set new base dir
    elseif newDirBase

            dirSearch = dirName;
            if ~strcmp(dirSearch(end), filesep)
                dirSearch = [dirSearch filesep];
            end

            varargout{1} = cellfun(@(fName) fullfile(newDir, fName(strfind(fName, dirSearch) + length(dirSearch):end))', dirFileList, 'UniformOutput', false);

    % output as-s
    elseif nargin == 2 && ~varargin{1}
        varargout{1} = dirFileList;
        
    end


end
