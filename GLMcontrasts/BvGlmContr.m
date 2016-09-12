function BvGlmContr(InputStruct)

% @ Niels R. Disbergen, v0.4
% adjusted for sharing, Aug 2016
%
% This code builds GLM contrasts based on BVQX GLM files. GLM data is
% masked if a msk-file is declared, contrast(s) computed, and *.vmp's 
% saved. Code requires a vmp-file which will be modified, hence needs to 
% have correct meta-data for vmr-linkage. VMP-files are created per 
% individual contrast as well as one master-vmp with all contrasts. Note 
% this is a relatively bare-bone function with limited checks, hence it 
% should be employed accordingly.
%
%
% Syntax:
%   BvGlmContr(InputStruct)
%
% Input:
% Struct with following field names (case-sensitive):
%
%   Required:
%       'GLM_FILE'       = Full path to Brainvoyager GLM file
%       'VMP_FILE'       = Full path to VMP file
%        CONTR_MAT       = Matrix containing contrast values for Beta's as
%                          fitted in the GLM [n-predictors * n-contrasts]
%       'CONTR_NAME_MAT' = Names to save contrasts with {1, n-contrasts}
%
%   Optional: 
%   If not declared or incorrectly formatted, set to empty
%       'MSK_FILE'       = Full path to the mask-file
%
% Example:
%   DatIn.GLM_FILE = 'C:/Imaging/GLM_file.glm';
%   DatIn.VMP_FILE = 'C:/Imaging/VMO_file.vmp';
%   DatIn.CONTR_MAT = [1 1 zeros(1,109); 1 -1 zeros(1,109)]';
%   DatIn.CONTR_NAME_MAT = {'MainEffSound' 'Contr_SoundSilence'};
%   DatIn.MSK_FILE = 'C:/Imaging/MASK_file.msk';
%   BvGlmContr(DatIn);
%


%% Parse input

    pObj = inputParser;
    pObj.CaseSensitive = true;
    pObj.KeepUnmatched = true;
    pObj.FunctionName = mfilename;

    % required vars
    varsReq = {'GLM_FILE', 'VMP_FILE', 'CONTR_MAT', 'CONTR_NAME_MAT'};
    valReq = {@(x)exist(x,'file')==2 @(x)exist(x,'file')==2 @isnumeric @(x)iscell(x)};

    N_VARS_REQ = length(varsReq);
    for cntReq = 1:N_VARS_REQ
        addRequired(pObj,varsReq{cntReq},valReq{cntReq})
    end

    % if not or incorrectly assigned, set empty
    addParameter(pObj,'MSK_FILE', [], @(x) exist(x,'file')==2);

    parse(pObj, InputStruct.(varsReq{1}), InputStruct.(varsReq{2}), InputStruct.(varsReq{3}), InputStruct.(varsReq{4}), InputStruct)

    StIn = pObj.Results;


%% Check and create

    vmpSavePath = fileparts(StIn.VMP_FILE);
    if exist(vmpSavePath,'dir')~=7
        mkdir(vmpSavePath)
    end

    % currently equal to vmp path, personally use different save path for
    % contrast vmp's
    mainContSavePath = vmpSavePath;
    if exist(mainContSavePath,'dir')~=7
        mkdir(mainContSavePath)
    end

    % if msk-file declard, call masking
    if ~isempty(StIn.MSK_FILE)
        mskDat=1;
    else
        mskDat=0;
    end

    nContr = size(StIn.CONTR_MAT,2);

    if size(StIn.CONTR_NAME_MAT,2)~=nContr
        MEname = MException('BvGlmContr:ContrNames:TooLittleNames', 'Number of contrast names (%i) unequal to number of contrasts (%i)',size(StIn.CONTR_NAME_MAT,2),nContr);
        throw(MEname)
    end


%% Load GLM & VMP data

    fprintf('Loading data \n')

    glmDat  = xff(StIn.GLM_FILE);

    mapSize = size(glmDat.GLMData.MultipleRegressionR);
    nPred   = glmDat.NrOfPredictors;
    df1     = glmDat.NrOfTimePoints-nPred;
    SStotal = double(glmDat.GLMData.MCorrSS);

    % get GLM beta-map and reshape to vector
    glmBetas2D = double(reshape(glmDat.GLMData.BetaMaps,prod(mapSize),nPred));

    vmpDat = xff(StIn.VMP_FILE);
    vmpDat.Map.DF1 = df1;

    if sum(size(StIn.CONTR_MAT) ~= [nPred nContr])~=0
        MEname = MException('BvGlmContr:ContrMat:MatNotCorrSize', 'Contrast matrix size does not match n-predictors*n-contrasts');
        throw(MEname)
    end


%% Mask data if msk-file declared
   
    if mskDat
        
        fprintf('Masking GLM data with "%s" \n',StIn.MSK_FILE)
        
        msk = xff(StIn.MSK_FILE);
        % reshape msk to vector and mask 2-d betas
        glmBetas2D(reshape(msk.Mask,prod(mapSize),1)==0,:)=0;
        
        mskLogiZero = msk.Mask==0;
        SStotal(mskLogiZero) = 0; % mask ss-total
        msk.ClearObject;

    end


%% Variables for contrasts

    % For details, see http://support.brainvoyager.com/installation-introduction/23-file-formats/457-developer-guide-the-format-of-glm-files-v4.html
    %   VARresiduals = SStotal * (1 - R2) / (NTimePoints - NAllPredictors)

    R2 = double(glmDat.GLMData.MultipleRegressionR).^2;
    varRes = SStotal.*(1-R2) ./(df1);
    
    if mskDat
        varRes(mskLogiZero) = 0;        
        [~,mskSaveName]= fileparts(StIn.MSK_FILE);
        mskSaveName = sprintf('_msk-%s',mskSaveName);
    else
        mskSaveName=[];
    end

    varRes2D = varRes(:);


%% Build contrasts, compute FDR for T's, save VMPs

    fprintf('Building contrasts \n')
    
    T   = zeros([mapSize nContr]);
    T2D = zeros(prod(mapSize),nContr);
    
    % vmp with all maps
    allVmp = vmpDat.CopyObject;
    allVmp.NrOfMaps = nContr;

    % all contrasts saved in individual VMPs (indivVmp) as well as one 
    % with all contrasts
    for cntContr = 1:nContr

        indivVmp = vmpDat.CopyObject;
        indivVmp.Map.Name = StIn.CONTR_NAME_MAT{1,cntContr};

        % t = c'b / sqrt(VARresiduals * c'(X'X)-1c)
        T2D(:,cntContr) = MrGlmContrT2d(glmBetas2D, StIn.CONTR_MAT(:,cntContr),varRes2D,glmDat.iXX);
        T(:,:,:,cntContr) = reshape(T2D(:,cntContr),mapSize);

        [indivVmp.Map.FDRThresholds(:,2), indivVmp.Map.FDRThresholds(:,3)] = CalcFdrMri(indivVmp.Map.FDRThresholds(:,1), T2D(:,cntContr), df1);

        indivVmp.Map.VMPData = T(:,:,:,cntContr);

        indivVmp.SaveAs(fullfile(mainContSavePath,sprintf('%s%s.vmp',StIn.CONTR_NAME_MAT{1,cntContr},mskSaveName)));
        
        allVmp.Map(cntContr) = indivVmp.Map;
        indivVmp.ClearObject;

    end

    allVmp.SaveAs(fullfile(mainContSavePath,sprintf('AllContrMaps%s.vmp',mskSaveName)));
    allVmp.ClearObject;


end


function [T2D] = MrGlmContrT2d(Betas2D,contrMat,varRes2D,iXX)
%
% @ Niels R. Disbergen
%
% Calcualte 2D-T's for contrasts with GLM Betas
%
% Syntax: 
%   [T2D] = MRGLMContrT2D(Betas2D,contrMat,varRes2D,iXX)
%
% Betas2D  = glm betas vector
% contrMat = contrast coded * n-contr
% varRes2D = variance residuals, ordered as Betas
% iXX      = (X*X')^-1
%

    narginchk(4,4)
    
    nContr = size(contrMat,2);
    T2D    = nan(size(Betas2D,1),nContr);

    for cntContr = 1:nContr
        T2D(:,cntContr) = (Betas2D*contrMat(:,cntContr)) ./ ( sqrt(contrMat(:,cntContr)'*iXX*contrMat(:,cntContr)*varRes2D) );
    end

end


function [tID, tNp, varargout] = CalcFdrMri(qVec, T2D, df1)

% @Niels Disbergen
% v1.0 FDR for T's, 21-Oct-2015
%
% This function calcualates FDR values with q's on T's at a given df and 
% returns both the cV=1 and cV=ln(V)+EulerGamma FDR values, optinally also 
% associated p-values are returned. Implementation of FDR from Genovese, 
% Lazar, & Nichols 2002 and results comparable to BrainVoyager 2.8
% FDR estimation.
% 
%
% Input:
%   qVec = vector of q(s) for FDR
%   T2D = vector of voxels T-values 
%   df1 = degrees of freedom for t-dist; typically (N-Volumes)-(N-Predictors)
%
% Output:
%   tID = independence or positive dependence threshold t-value (cV=1; BVQX CritStd)
%   tNp = non-parametric threshold t-value (cV=ln(V)+EulerGamma; BVQX CritCons)
%   pID = corresponding p-values for tID
%   pNp = corresponding p-values for tNp
%
% Syntax:
%   [tID, tNp]           = calcFDRmri(qVec,T2D,df1);
%   [tID, tNp, pID]      = calcFDRmri(qVec,T2D,df1);
%   [tID, tNp, pID, pNp] = calcFDRmri(qVec,T2D,df1);


%% Check & declare

    narginchk(3,3)
    
    if isvector(T2D)
        nVoxs=length(T2D);
    else
        error('T2D is not a vector')
    end

    if isvector(qVec)
        nQvals=length(qVec);
    else
        error('qVec is not a vector')
    end

    tNp = zeros(nQvals,1); 
    tID = zeros(nQvals,1); 
    pThrNp = zeros(nQvals,1);
    pThrID = zeros(nQvals,1);


%% Calc thresh t's & p's for q's
    % see Lazar, & Nichols 2002 for details

    % sort p's; not tossing nan!
    pVals = sort((2*tcdf(abs(T2D), df1, 'upper')),'ascend'); 

    for cntQ=1:nQvals

        % find p's matching for q
        tmpPid = pVals(find(pVals<=((1:nVoxs)'/nVoxs)*double(qVec(cntQ)/1), 1, 'last'));
        
        if ~isempty(tmpPid)
            pThrID(cntQ,1) = tmpPid;
        else
            pThrID(cntQ,1) = 1;
            warning('No voxel exceeds FDR-thresh for q=%1.4f @ cV=1', qVec(cntQ))
        end
        
        % get threshold t's from p's
        tID(cntQ,1) = abs(tinv(pThrID(cntQ,1), df1));

        % Non-parametric version
        tmpPidNp = pVals(find(pVals<=((1:nVoxs)'/nVoxs)*double(qVec(cntQ)/(log(nVoxs)+vpa(eulergamma))), 1, 'last' ));

        if ~isempty(tmpPidNp)
            pThrNp(cntQ,1) = tmpPidNp;
        else
            pThrNp(cntQ,1) = 1;
            warning('No voxel exceeds FDR-thresh q=%1.4f @ cV=ln(V)+E',qVec(cntQ))
        end

        tNp(cntQ,1)    = abs(tinv(pThrNp(cntQ,1), df1));

    end


%% Output

    if nargout>=3
        varargout{1} = pThrID;
        if nargout==4
            varargout{2} = pThrNp;
        end
    end


end