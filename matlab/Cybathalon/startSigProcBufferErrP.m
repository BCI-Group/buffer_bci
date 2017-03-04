%----------------------------------------------------------------------
% Initializes variables that will be used for the signal processor and
% calls the signal processor related to the Error Related Potential signal
% processing.
%
% Author: Alejandro González Rogel (s4805550)
%         Marzieh Borhanazad (s4542096)
%         Ankur Ankan (s4753828)
% Forked from https://github.com/jadref/buffer_bci
%----------------------------------------------------------------------
configureExp;
imSigProcBufferErrP('epochEventType','stimulus_errp.target','freqband',freqband_errp,...
                   'clsfr_type','erp','trlen_ms',trlen_ms_ErrP,...
                   'calibrateOpts',calibrateOpts_errp,'trainOpts',...
                   trainOpts_errp,'timeout_ms',timeout_ms,'verb',verb,'wait_end',wait_end);
