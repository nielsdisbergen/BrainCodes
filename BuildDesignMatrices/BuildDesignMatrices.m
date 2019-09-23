function BuildDesignMatrices(InputStruct)
%
% @ Niels R. Disbergen
% adjusted for sharing, v1.4 - April 2016
%
% This code builds design matrices from BrainVoyager protocol files for 
% single and multi study declaration. PRT files and N_VOLUMES need to be
% provided. Optionally: motion parameter predictors, HRF-parameters, 
% convolving with HRF, predictor exclusion, mdm options, run and 
% participant naming.
%
% !! When this function is called it adds run data to the global variable 
% DesignMatDat, which has to be declared before running this fucntion. As
% this function merely adds data to the structure, rerun with equal inputs
% will result in replication. This implementation is intentional; in case
% runs need to be replaced, remove these from the DeignMatDat struct prior
% to (re-)calling !!
%
% Note this is a relatively bare-bone function with limited checks, hence 
% it should be employed accordingly.
% 
% HRF model via the spm_hrf function, hardcoded
% 
% Syntax:
% BuildDesignMatrices(InputStruct)
%
% Input:
% Struct with following field names (case-sensitive):
%
%   Required:
%       'PRT_FILE' = full path to PRT file
%        N_VOLUMES = total number of volumes in the run
%
%
%   Optional: 
%   When not declared, they are set to default
%       'MOTPAR_FILE' = full path to BVQX motion parameter file (default = no
%                       motion paramaters added)
%
%        PARAMS_HRF   = struct with parameters to estimate HRF for convolution, 
%                       adopting spm_hrf function. Required fields:
%                       TR(ms), respdel, undshdel, respdisp, undshdisp, 
%                       respundshrat onset; Default: TR=2000, respdel=6, 
%                       undshdel=16, respdisp=1, undshdisp=1,
%                       respundshrat=6, onset=0; see spm_hrf for reference
%
%        EXCL_PREDS   = predictor names to be excluded, has to be equal to 
%                       the names as declared in the PRT! default = {}: include all
%
%        CONV_PRED    = convolve boxcar/fir predictors with hrf (default =
%                       false)
%
%        PARAMS_MDM   = struct with parameters for MDM building, fields:
%                       RFXGLM, PSCtransform, zTransform, separatePreds. If
%                       declared, a MDM will be build after that respective 
%                       run, taking into account all the sdms included in 
%                       the global variable DesignMatDat. Default = []: no
%                       mdm is built
%
%       'RUN_NAME'    = run name to save in DesignMatDat (default = Run%i, 
%                       i = nth DesignMatDat run entry)
%
%       'PP_NAME'     = subject name for mdm saving (default='Subject')
%

    narginchk(1,1)


%% Parsing options

    global DesignMatDat;

    HrfBase = struct('TR', 2000,'respdel', 6,'undshdel', 16,'respdisp', 1,'undshdisp', 1,'respundshrat', 6,'onset', 0);

    if ~isfield(DesignMatDat, 'sdmSaveNames')
        DesignMatDat.sdmSaveNames = {};
    end


%% Parse input

    pObj = inputParser;
    pObj.CaseSensitive = true;
    pObj.KeepUnmatched = true;
    pObj.FunctionName = mfilename;

    % required vars and evaluations
    varsReq = {'PRT_FILE' 'N_VOLUMES'};
    chkVals = {@(x) exist(x,'file')==2, @(x) mod(x,1)==0};

    for cntReq = 1:length(varsReq)
        addRequired(pObj,varsReq{cntReq},chkVals{cntReq})
    end

    % if below are not assigned, optional is set
     addParameter(pObj,'MOTPAR_FILE', [], @(x) exist(x,'file')==2)
     addParameter(pObj,'PARAMS_HRF', HrfBase, @(x) isstruct(x) & sum(isfield(x,fieldnames(HrfBase)))==length(fieldnames(HrfBase)))
     addParameter(pObj,'EXCL_PREDS', {}, @iscellstr)
     addParameter(pObj,'CONV_PRED', false, @islogical)
     addParameter(pObj,'PARAMS_MDM', [], @(x) isstruct(x) & sum(isfield(x,{'RFXGLM', 'PSCtransform','zTransform','separatePreds'}))==4)
     addParameter(pObj,'RUN_NAME', sprintf('Run%i', size(DesignMatDat.sdmSaveNames,1)+1), @ischar)
     addParameter(pObj,'PP_NAME', 'Subject', @ischar)

     parse(pObj, InputStruct.(varsReq{1}), InputStruct.(varsReq{2}), InputStruct)

     InpDat = pObj.Results;


%% Check and create

    [prtPath, sdmNameBase, ~] = fileparts(InpDat.PRT_FILE); % save-location sdm, save-name base sdm

    % if no MDMparams, no mdm building
    if ~isempty(InpDat.PARAMS_MDM)
        prtMdm = true;
    else
        prtMdm = false;
    end

    % if no motion parameter file declared, MCT predictors not added
    if ~isempty(InpDat.MOTPAR_FILE)
        inclMct = true;
    else
        inclMct = false;
    end

    % warning if unconvolved DM
    if ~InpDat.CONV_PRED
        warning('Building Unconvolved Designmatrix');
        pause(2);
    end


%% Build predictors   

    fprintf('Building SDM for "%s" \n', InpDat.PRT_FILE)

    % build hrf
    [HrfBase, paraHrf] = spm_hrf_desimat(InpDat.PARAMS_HRF.TR/1000, [InpDat.PARAMS_HRF.respdel, InpDat.PARAMS_HRF.undshdel, InpDat.PARAMS_HRF.respdisp, InpDat.PARAMS_HRF.undshdisp, InpDat.PARAMS_HRF.respundshrat, InpDat.PARAMS_HRF.onset]);

    % set N-volumes
    PredInf.totalVols = InpDat.N_VOLUMES;

    % load prt data
    prtRead = xff(InpDat.PRT_FILE);

    % declare variables
    PredInf.nDeclPreds = size(prtRead.Cond, 2);
    PredInf.nExclPreds = size(InpDat.EXCL_PREDS, 2);
    PredInf.nTotalDeclPreds = PredInf.nDeclPreds - PredInf.nExclPreds;

    PredInf.predColors = zeros(PredInf.nTotalDeclPreds, 3);
    PredInf.predNames  = cell(1,1);

    declPredHrf = [];

    cntPrtDeclPred = 0; % count N-predictors included
    declPredBoxcarStore = zeros(PredInf.totalVols, PredInf.nTotalDeclPreds);

    % build predictors and convolve boxcars with HRF if called
    for cntDeclPred = 1:PredInf.nDeclPreds

        exclPred = 0;

        if PredInf.nExclPreds ~= 0
            for cntExclPred = 1:PredInf.nExclPreds
                if strcmp(prtRead.Cond(cntDeclPred).ConditionName, InpDat.EXCL_PREDS{cntExclPred})
                    exclPred = 1;
                end
            end
        end

        if ~exclPred

            cntPrtDeclPred = cntPrtDeclPred + 1;

            PredInf.predNames(1, cntPrtDeclPred) = prtRead.Cond(cntDeclPred).ConditionName;
            PredInf.predColors(cntPrtDeclPred, :) = prtRead.Cond(cntDeclPred).Color;
            
            
            % get on-off from preds
            onOffPred = prtRead.Cond(cntDeclPred).OnOffsets;

            % build box-cars for predictors
            declPredBoxcar = zeros(PredInf.totalVols, PredInf.nTotalDeclPreds);
            for cntOnOffSet = 1:prtRead.Cond(cntDeclPred).NrOfOnOffsets
                if sum(onOffPred) ~= 0
                    declPredBoxcar(onOffPred(cntOnOffSet, 1):onOffPred(cntOnOffSet, 2), cntPrtDeclPred) = 1;
                    declPredBoxcarStore(onOffPred(cntOnOffSet, 1):onOffPred(cntOnOffSet, 2), cntPrtDeclPred) = 1;
                end
            end

            % convolve boxcar with hrf if called
            if ~InpDat.CONV_PRED
                tempPredHrf = declPredBoxcar(:, cntPrtDeclPred);
            else
                try
                    tempPredHrf = conv(declPredBoxcar(:, cntPrtDeclPred), HrfBase);
                catch ME
                    MEconv = MException('BuildDesignMatrices:BoxcarConvError', 'Error while convolving for "%s"', InpDat.PRT_FILE);
                    MEconv = addCause(MEconv, ME);
                    throw(MEconv)
                end
            end

            % trim convolution at total volumes
            declPredHrf(:, cntPrtDeclPred) = tempPredHrf(1:PredInf.totalVols, :);

        end

    end

    prtRead.ClearObject;


%% Store variables and add MCT if declared

    if inclMct

        % read MCT
        motionParam = xff(InpDat.MOTPAR_FILE);

        if size(motionParam.SDMMatrix, 1) ~= InpDat.N_VOLUMES
            throw(MException('BuildDesignMatrices:IncludeMCT:MCTvolumessNotEqToDeclaredVolumes','Error: motion parameter file has %i volumes, declared volumes has %i', size(motionParam.SDMMatrix, 1), InpDat.N_VOLUMES));
        end

        PredInf.predNames = [PredInf.predNames motionParam.PredictorNames 'Constant'];
        PredInf.nMCTparam = size(motionParam.SDMMatrix, 2);

        PredInf.nAllPreds = PredInf.nTotalDeclPreds + PredInf.nMCTparam;

        % add to design matrix preds, motion & intercept
        designMat = [declPredHrf motionParam.SDMMatrix ones(PredInf.totalVols, 1)];

        motionParam.ClearObject;
        currSdmName = sprintf('%s_inclMCT.sdm', sdmNameBase); %save-name

    else

        PredInf.nAllPreds = PredInf.nTotalDeclPreds;
        PredInf.predNames(1, end+1) = 'Constant';

        designMat = [declPredHrf ones(PredInf.totalVols, 1)];
        currSdmName = sprintf('%s.sdm', sdmNameBase); %save-name

    end

    DesignMatDat.sdmSaveNames = [DesignMatDat.sdmSaveNames; currSdmName];

    DesignMatDat.(InpDat.RUN_NAME) = struct('PredictorNames', {PredInf.predNames}, 'PredictorColors' , {PredInf.predColors}, 'ExcludedPredictors', {InpDat.EXCL_PREDS}, 'BoxCars', declPredBoxcar, 'DesignMatrix', designMat,'hrf_imp', HrfBase, 'hrf_param', paraHrf);

    DesignMatDat.(InpDat.RUN_NAME).PredInfo = PredInf;

    writeSDM(PredInf, DesignMatDat, currSdmName, InpDat, prtPath);


%% Build MDM if called

    if prtMdm
        fprintf('MDM for %s \n', InpDat.PP_NAME)
        [DesignMatDat] = writeMDM(DesignMatDat, InpDat, inclMct, prtPath);
        display('Finished building SDM & MDM')
    else
        display('Finished building SDM')
    end


end


function writeSDM(PredInf, DesignMatDat, currSdmName, InpDat, fmrPath)
% This function handles all writing operations for the SDM filetype

%% Build BrainVoyager *.sdm variables

    prtSDM{1} = 'FileVersion: 1';
    prtSDM{2} = sprintf('NrOfPredictors: %i', PredInf.nAllPreds + 1); % +1 for intercept
    prtSDM{3} = sprintf('NrOfDataPoints: %i', PredInf.totalVols);
    prtSDM{4} = sprintf('IncludesConstant: 1');
    prtSDM{5} = sprintf('FirstConfoundPredictor: %i', PredInf.nTotalDeclPreds + 1);

    % build predictor colors
    for cntPred = 1:PredInf.nTotalDeclPreds
        if cntPred ~= 1
            prtSDM{6} = sprintf('%s   %i %i %i', prtSDM{6}, PredInf.predColors(cntPred, :));
        else
            prtSDM{6} = sprintf('%i %i %i', PredInf.predColors(cntPred, :));
        end
    end

    % motionparams + intercept colors
    for cntPred = 1:PredInf.nMCTparam + 1 
        prtSDM{6} = sprintf('%s   %i %i %i', prtSDM{6}, [255 255 255]);
    end

    % build predictor names
    prtSDM{7} = '';
    for cntPred = 1:size(PredInf.predNames, 2)
        if cntPred ~= 1
            prtSDM{7} = sprintf('%s "%s"', prtSDM{7}, PredInf.predNames{1, cntPred});
        else
            prtSDM{7} = sprintf('"%s"', PredInf.predNames{1, cntPred});
        end
    end


%% Write sdm-file

    sdmSaveName = fullfile(fmrPath, currSdmName);

    if exist(fmrPath, 'dir') ~= 7
        mkdir(fmrPath)
    end

    dlmwrite(sdmSaveName, '')
    % printData contains default options on dlmwrite()
    printData(prtSDM{1}, 0, sdmSaveName)

    for cntPrt = 2:7
        if cntPrt == 2 || cntPrt == 3 || cntPrt == 6 
            printData(prtSDM{cntPrt}, 1, sdmSaveName)
        else
            printData(prtSDM{cntPrt}, 0, sdmSaveName)
        end
    end

    dlmwrite(sdmSaveName, DesignMatDat.(InpDat.RUN_NAME).DesignMatrix, '-append', 'roffset', 0, 'delimiter', ' ')


end


function [DesignMatDat] = writeMDM(DesignMatDat, InpDat, inclMct, fmrPath)
% This function handles all writing operations for the MDM filetype

%% Build BrainVoyager variables

    prtMDM{1} = 'FileVersion: 3';
    prtMDM{2} = 'TypeOfFunctionalData: FMR';
    prtMDM{3} = sprintf('RFX-GLM: %i', InpDat.PARAMS_MDM.RFXGLM);
    prtMDM{4} = sprintf('PSCTransformation: %i', InpDat.PARAMS_MDM.PSCtransform);
    prtMDM{5} = sprintf('zTransformation: %i', InpDat.PARAMS_MDM.zTransform);
    prtMDM{6} = sprintf('SeparatePredictors: %i', InpDat.PARAMS_MDM.separatePreds);
    
    nRuns = size(DesignMatDat.sdmSaveNames,1);
    prtMDM{7} = sprintf('NrOfStudies: %i', nRuns);


%% Check and create

    if inclMct
        modSup = '_inclMCT';
    else
        modSup = '';
    end

    if ispc
        slshIds = strfind(fmrPath, '\');
    else
        slshIds = strfind(fmrPath, '/');
    end
    
    if ~isempty(slshIds)
        mdmPath = fmrPath(1:slshIds(end));
    else
        mdmPath = fmrPath;
    end
    
    DesignMatDat.mdmSavename =  fullfile(mdmPath, sprintf('%s_fmrMDM_%iruns%s.mdm', InpDat.PP_NAME, nRuns, modSup));


%% Write mdm-file

    dlmwrite(DesignMatDat.mdmSavename, '')

    for cntPrt = 1:size(prtMDM, 2)
        if cntPrt == 2 || cntPrt == 5 || cntPrt == 6 
            printData(prtMDM{cntPrt}, 0, DesignMatDat.mdmSavename)
        else
            printData(prtMDM{cntPrt}, 1, DesignMatDat.mdmSavename)
        end
    end

    for cntStudy = 1:nRuns
        sdmFullPath = fullfile(fmrPath, DesignMatDat.sdmSaveNames{cntStudy});
        printData(sprintf('"%s" "%s"', InpDat.FMR_FILE, sdmFullPath),0 , DesignMatDat.mdmSavename)
    end


end

function printData(dataPrt, rOffs, printName)
    dlmwrite(printName, dataPrt, '-append', 'roffset', rOffs, 'delimiter', '')
end

function [hrf, p] = spm_hrf_desimat(RT,P)
    % Name-only adaptation of spm_hrf function for BuildDesignMatrices.m
    %
    % returns a hemodynamic response function
    % FORMAT [hrf,p] = spm_hrf(RT,[p]);
    % RT   - scan repeat time
    % p    - parameters of the response function (two gamma functions)
    %
    %							defaults
    %							(seconds)
    %	p(1) - delay of response (relative to onset)	   6
    %	p(2) - delay of undershoot (relative to onset)    16
    %	p(3) - dispersion of response			   1
    %	p(4) - dispersion of undershoot			   1
    %	p(5) - ratio of response to undershoot		   6
    %	p(6) - onset (seconds)				   0
    %	p(7) - length of kernel (seconds)		  32
    %
    % hrf  - hemodynamic response function
    % p    - parameters of the response function
    %_______________________________________________________________________
    % @(#)spm_hrf.m	2.7 Karl Friston 99/05/17

    % global parameter
    %-----------------------------------------------------------------------
    global fMRI_T;
    if isempty(fMRI_T), fMRI_T = 16; end;

    % default parameters
    %-----------------------------------------------------------------------
    p = [6 16 1 1 6 0 32];
    if nargin > 1
        p(1:length(P)) = P;
    end

    % modelled hemodynamic response function - {mixture of Gammas}
    %-----------------------------------------------------------------------
    dt = RT/fMRI_T;
    u = [0:(p(7)/dt)] - p(6)/dt;
    hrf = spm_Gpdf_DesiMat(u, p(1)/p(3), dt/p(3)) - spm_Gpdf_DesiMat(u, p(2)/p(4), dt/p(4))/p(5);
    hrf = hrf([0:(p(7)/RT)] * fMRI_T + 1);
    hrf = hrf'/sum(hrf);

end

function f = spm_Gpdf_DesiMat(x,h,l)
    % Name-only adaptation of spm_Gpdf function to BuildDesignMatrices!
    %
    % Probability Density Function (PDF) of Gamma distribution
    % FORMAT f = spm_Gpdf_DesiMat(g,h,l)
    %
    % x - Gamma-variate   (Gamma has range [0,Inf) )
    % h - Shape parameter (h>0)
    % l - Scale parameter (l>0)
    % f - PDF of Gamma-distribution with shape & scale parameters h & l
    %_______________________________________________________________________
    %
    % spm_Gpdf_DesiMat implements the Probability Density Function of the Gamma
    % distribution.
    %
    % Definition:
    %-----------------------------------------------------------------------
    % The PDF of the Gamma distribution with shape parameter h and scale l
    % is defined for h>0 & l>0 and for x in [0,Inf) by: (See Evans et al.,
    % Ch18, but note that this reference uses the alternative
    % parameterisation of the Gamma with scale parameter c=1/l)
    %
    %           l^h * x^(h-1) exp(-lx)
    %    f(x) = ---------------------
    %                gamma(h)
    %
    % Variate relationships: (Evans et al., Ch18 & Ch8)
    %-----------------------------------------------------------------------
    % For natural (strictly +ve integer) shape h this is an Erlang distribution.
    %
    % The Standard Gamma distribution has a single parameter, the shape h.
    % The scale taken as l=1.
    %
    % The Chi-squared distribution with v degrees of freedom is equivalent
    % to the Gamma distribution with scale parameter 1/2 and shape parameter v/2.
    %
    % Algorithm:
    %-----------------------------------------------------------------------
    % Direct computation using logs to avoid roundoff errors.
    %
    % References:
    %-----------------------------------------------------------------------
    % Evans M, Hastings N, Peacock B (1993)
    %       "Statistical Distributions"
    %        2nd Ed. Wiley, New York
    %
    % Abramowitz M, Stegun IA, (1964)
    %       "Handbook of Mathematical Functions"
    %        US Government Printing Office
    %
    % Press WH, Teukolsky SA, Vetterling AT, Flannery BP (1992)
    %       "Numerical Recipes in C"
    %        Cambridge
    %_______________________________________________________________________
    % @(#)spm_Gpdf_DesiMat.m	2.2 Andrew Holmes 99/04/26

    %-Format arguments, note & check sizes
    %-----------------------------------------------------------------------
    if nargin<3, error('Insufficient arguments'), end

    ad = [ndims(x);ndims(h);ndims(l)];
    rd = max(ad);
    as = [	[size(x),ones(1,rd-ad(1))];...
        [size(h),ones(1,rd-ad(2))];...
        [size(l),ones(1,rd-ad(3))]     ];
    rs = max(as);
    xa = prod(as,2)>1;
    if sum(xa)>1 && any(any(diff(as(xa,:)),1))
        error('non-scalar args must match in size'), end

    %-Computation
    %-----------------------------------------------------------------------
    %-Initialise result to zeros
    f = zeros(rs);

    %-Only defined for strictly positive h & l. Return NaN if undefined.
    md = ( ones(size(x))  &  h>0  &  l>0 );
    if any(~md(:)), f(~md) = NaN;
        warning('Returning NaN for out of range arguments'), end

    %-Degenerate cases at x==0: h<1 => f=Inf; h==1 => f=l; h>1 => f=0
    ml = ( md  &  x==0  &  h<1 );
    f(ml) = Inf;
    ml = ( md  &  x==0  &  h==1 ); if xa(3), mll=ml; else mll=1; end
    f(ml) = l(mll);

    %-Compute where defined and x>0
    Q  = find( md  &  x>0 );
    if isempty(Q), return, end
    if xa(1), Qx=Q; else Qx=1; end
    if xa(2), Qh=Q; else Qh=1; end
    if xa(3), Ql=Q; else Ql=1; end

    %-Compute
    f(Q) = exp( (h(Qh)-1).*log(x(Qx)) +h(Qh).*log(l(Ql)) - l(Ql).*x(Qx)...
        -gammaln(h(Qh)) );
end
