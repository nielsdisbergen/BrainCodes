function [tID, tNp, varargout] = CalcFdrFmri(qVec, t2D, df1)

% @Niels R. Disbergen
% v1.0 FDR for T's, 21-Oct-2015
%
% This function calcualates FDR values with q's on T's at a given df and
% returns both the cV=1 and cV=ln(V)+EulerGamma FDR values, optinally also
% associated p-values are returned. Implementation of FDR from Genovese,
% Lazar & Nichols 2002 and results comparable to BrainVoyager 2.8
% FDR estimation. For details see Lazar & Nichols 2002.
%
% Input:
%   qVec = vector of q(s) for FDR
%   t2D = vector of voxels T-values
%   df1 = degrees of freedom for t-dist; typically N-Volumes minus N-Predictors
%
% Output:
%   tID = independence or positive dependence threshold t-value (cV=1; BVQX CritStd)
%   tNp = non-parametric threshold t-value (cV=ln(V)+EulerGamma; BVQX CritCons)
%   pID = corresponding p-values for tID
%   pNp = corresponding p-values for tNp
%
% Syntax:
%   [tID, tNp]           = CalcFdrFmri(qVec, t2D, df1);
%   [tID, tNp, pID]      = CalcFdrFmri(qVec, t2D, df1);
%   [tID, tNp, pID, pNp] = CalcFdrFmri(qVec, t2D, df1);
%

%% Check input vars

    narginchk(3,3)

    if isvector(t2D)
        nVoxs = length(t2D);
    else
        throw(MException('CalcFdrFmri:TvaluesNotVector', 'Error: input of t2D is not a vector'))
    end

    if isvector(qVec)
        nQvals = length(qVec);
    else
        throw(MException('CalcFdrFmri:TvaluesNotVector', 'Error: input of qVec is not a vector'))
    end

    if ~isnumeric(df1) || numel(df1) ~= 1
        throw(MException('CalcFdrFmri:dfNotValid', 'Error: input of df is not valid'))
    end


%% Calc threshold t's & p's for q's

    tNp = zeros(nQvals, 1);
    tID = zeros(nQvals, 1);
    pThrNp = zeros(nQvals, 1);
    pThrID = zeros(nQvals, 1);

    pValsSorted = sort((2 * tcdf(abs(t2D), df1, 'upper')), 'ascend'); % NOTE: not tossing nan!

    for cntQval = 1:nQvals

        tmpPid = pValsSorted(find(pValsSorted <= ((1:nVoxs)' / nVoxs) * double(qVec(cntQval) / 1), 1, 'last' ));

        if ~isempty(tmpPid)
            pThrID(cntQval, 1) = tmpPid;
        else
            pThrID(cntQval, 1) = 1;
            warning('No vox exceeds FDR-thresh for q=%1.4f @ cV=1', qVec(cntQval))
        end

        tID(cntQval,1) = abs(tinv(pThrID(cntQval, 1), df1));

        tmpPidNp = pValsSorted(find(pValsSorted<=((1:nVoxs)'/nVoxs)*double(qVec(cntQval)/(log(nVoxs)+vpa(eulergamma))), 1, 'last' )); % Non-parametric!

        if ~isempty(tmpPidNp)
            pThrNp(cntQval, 1) = tmpPidNp;
        else
            pThrNp(cntQval, 1) = 1;
            warning('No voxel exceeds FDR-thresh q=%1.4f @ cV=ln(V)+E', qVec(cntQval))
        end

        tNp(cntQval,1) = abs(tinv(pThrNp(cntQval,1), df1));

    end


%% Output

    if nargout >= 3
        varargout{1} = pThrID;

        if nargout == 4
            varargout{2} = pThrNp;

        end
    end

end
