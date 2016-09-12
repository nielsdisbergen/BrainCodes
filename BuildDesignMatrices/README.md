## BuildDesignMatrices.m ##

Code dependency towards [NeuroElf](http://neuroelf.net/ "http://neuroelf.net/") on the path, tested with v0.9d and 1.0.

This code builds design matrices from BVQX protocol files for single and
multi study declaration. PRT files as well as number of volumes need to be provided. Optionally: motion parameter predictors,
convolving with HRF, predictor exclusion, mdm options, run and
participant naming, ...

_When this function is called it adds run data to global variable
DesignMatDat, which has to be declared before first call._

Sometimes NeuroElf throws a warning: ```Could not parse numeric ARRAY SDMMatrix with u8str2double; retrying``` This should not cause any issues for building the design matrices; in case it does fail to parse an error should be provided instead.

Note this is a relatively bare-bone function with limited checks, hence it should be employed accordingly.

Usage example:
```matlab

global DesignMatDat;
DesignMatDat = [];

% if PARAMS_HRF is not declared, function assigns following std BV-hrf shape:
HrfBase = struct('TR',2000,'respdel',6,'undshdel',16,'respdisp',1,'undshdisp',1,'respundshrat',6,'onset',0);

% if MDMparams is declared, then MDM is built based on all runs contained in DesignMatDat.
% Example declaration, see BV manual for details:
MDMparams = struct('RFXGLM', 0, 'PSCtransform',  1, 'zTransform', 0,'separatePreds', 0);

for cntRun = 1:nRuns

    DM=[];

    DM.PP_NAME  = sprintf('S%i',cntRun);
    DM.RUN_NAME = sprintf('Run%i',cntRun);

    DM.N_VOLUMES = 175;

    DM.PRT_FILE = '~/Imaging/Prt_file.prt';
    DM.MOTPAR_FILE = '~/Imaging/Mct_file.mct'; % declared = added

    DM.PARAMS_HRF = HrfBase;

    DM.CONV_PRED = true; % by default false: FIR/boxcar model building, i.e. no deconvolution
    DM.EXCL_PREDS = {'rest'}; % not-declared = include all

    if cntRun == nRuns
        DM.PARAMS_MDM = MDMparams; % declared = built
    end

    BuildDesignMatrices(DM); % DesignMatDat updated by function

end

```

See code for more info on required and optional variables with their defaults; when variables are not, or incorrectly, declared default values are assigned, for example: `addParameter(pObj, 'EXCL_PREDS', {}, @iscellstr)` has a default value of `{}` when `EXCL_PREDS` is not defined or not a cell string.

Niels R. Disbergen - 2015
