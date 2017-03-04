call ..\..\utilities\findMatlab.bat
if %ismatlab%==1 (
  start "Matlab" /b %matexe% -r "configureExp;imSigProcBufferErrP('epochEventType','stimulus_errp.target','freqband',freqband_errp,'clsfr_type','erp','trlen_ms',trlen_ms_ErrP,'calibrateOpts',calibrateOpts_errp,'trainOpts',trainOpts_errp,'timeout_ms',timeout_ms,'verb',verb,'wait_end',wait_end);quit;" %matopts%
) else (
echo configureExp;imSigProcBufferErrP^('epochEventType','stimulus_errp.target','freqband',freqband_errp,'clsfr_type','erp','trlen_ms',trlen_ms_ErrP,'calibrateOpts',calibrateOpts_errp,'trainOpts',trainOpts_errp,'timeout_ms',timeout_ms,'verb',verb,'wait_end',wait_end^);quit; | %matexe% %matopts%
)
