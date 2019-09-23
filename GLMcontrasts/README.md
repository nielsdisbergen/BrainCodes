## BvGlmContr.m ##

This code builds GLM contrasts based on BVQX GLM output files. Code dependency towards [NeuroElf](http://neuroelf.net/ "http://neuroelf.net/") on the path, tested with v1.0

GLM data is masked if a \*.msk-file is declared, contrast(s) are computed, and \*.vmp's saved with updated FDRs. Code requires a vmp-file which will be modified, hence needs to have correct meta-data for vmr-linkage. VMP-files are created per individual contrast as well as one master-vmp with all contrasts.

Note this is a relatively bare-bone function with limited checks, hence it should be employed accordingly.

Usage example:
```matlab

GlmCtr.GLM_FILE = '~/GLM_file.glm'; % BrainVoyager GLM
GlmCtr.VMP_FILE = '~/VMP_file.vmp'; % To-be-modified VMP

% Contrast vector/matrix [n-predictors * n-contrasts]
GlmCtr.CONTR_MAT = [1 1 zeros(1, 109); 1 -1 zeros(1, 109)]';

% Save-names for contrasts {1, n-contrasts}
GlmCtr.CONTR_NAME_MAT = {'MainEffSound' 'Contr_SoundSilence'};

GlmCtr.MSK_FILE = '~/MASK_file.msk'; % Mask file, declared = apply to GLM-betas

BvGlmContr(GlmCo);

```

If the variable 'MSK_FILE' is not declared, the default value `[]` is assigned through `addParameter(pObj, 'MSK_FILE', [], @(x) exist(x, 'file') == 2)` and no mask will be applied.

Niels R. Disbergen
