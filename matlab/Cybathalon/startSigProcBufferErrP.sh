#!/bin/bash
cd `dirname ${BASH_SOURCE[0]}`
source ../../utilities/findMatlab.sh
if [[ $matexe == *matlab ]]; then  args=-nodesktop; fi
cat <<EOF | $matexe $args
configureExp;
imSigProcBufferErrP('epochEventType','stimulus_errp.target','freqband',[0.5 1 9.5 10],...
                   'clsfr_type','erp','trlen_ms',trlen_ms_ErrP,...
                   'calibrateOpts',calibrateOpts,'trainOpts',trainOpts,'timeout_ms',timeout_ms,'verb',verb);
%quit;
EOF
