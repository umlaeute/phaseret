function [c,newphase,tgrad,fgrad]=rtpghi(s,gamma,a,M,varargin)
%RTPGHI Real-Time Phase Gradient Integration
%   Usage:  c=rtpghi(s,gamma,a,M);
%           c=rtpghi(s,gamma,a,M,tol);
%           c=rtpghi(c,gamma,a,M,tol,mask);
%           c=rtpghi(c,gamma,a,M,tol,mask,usephase);
%           [c,newphase,usedmask,tgrad,fgrad] = rtpghi(...);
%
%   Input parameters:
%         s        : Initial coefficients.
%         gamma    : Window width factor.
%         a        : Hop factor.
%         M        : Number of channels.
%         tol      : Relative tolerance.
%         mask     : Mask for selecting known phase.
%         usephase : Explicit known phase.
%   Output parameters:
%         c        : Coefficients with the constructed phase.
%         newphase : Just the (unwrapped) phase.
%         usedmask : Mask for selecting coefficients with the new phase.
%         tgrad    : Relative time phase derivative.
%         fgrad    : Relative frequency phase derivative.
% 
%   `rtpghi(s,gamma,a,M)` creates complex DGT coefficients from their
%   absolute values *s* using the Real-Time Phase Gradient Heap Integration
%   algorithm. *s* must have been obtained as::
%
%       c = dgtreal(f,g,a,M);
%       s = abs(c);
%
%   and the algorithm attempts to recover *c*. Parameter *gamma* is window 
%   *g* specific and it can be computed using:
%
%   .. gamma = Cg*gl^2
%
%   .. math:: \gamma = C_g \mathit{gl}^2
%
%   where *gl* is the window length and *Cg* is a window specific constant. 
%   Both *Cg* and *gamma* can be obtained by calling |findwindowconstant|.
%
%   This function works entirely simiral to |pghi| except it is using
%   the real-time version of the algorithm. Please see help of |pghi| 
%   (resp. |constructphasereal| from LTFAT) for more details.
%
%   See also: dgtreal, idgtreal, rtpghi
%
%   References: ltfatnote040 ltfatnote043
%

%   AUTHORS: Zdenek Prusa
%

thismfilename = upper(mfilename);
complainif_notposint(a,'a',thismfilename);
complainif_notposint(M,'M',thismfilename);

definput.keyvals.tol=[1e-10];
definput.keyvals.mask=[];
definput.keyvals.lambda = [];
definput.keyvals.g = [];
definput.flags.phase={'timeinv','freqinv'};
definput.flags.variant={'normal','causal'};
[flags,kv,tol]=ltfatarghelper({'tol','mask'},definput,varargin);
g = kv.g;
[M2,N,W] = size(s);

if W>1
    error('%s: *s* must not be 3 dimensional.',thismfilename);
end

M2true = floor(M/2) + 1;

if M2true ~= M2
    error('%s: Mismatch between *M* and the size of *s*.',thismfilename);
end

abss = abs(s);

if flags.do_timeinv
    fgradmul = @(fgrad) -gamma/(a*M)*fgrad;
    tgradmul = @(tgrad) bsxfun(@plus,a*M/gamma*tgrad, 2*pi*a*(0:M2-1)'/M);
elseif flags.do_freqinv
    fgradmul = @(fgrad) bsxfun(@plus,-gamma/(a*M)*fgrad, -2*pi*a*(0:N-1)/M);
    tgradmul = @(tgrad) a*M/gamma*tgrad;    
end

logs=log(abss+realmin);
tt=-10;
logs(logs<max(logs(:))+tt)=tt;

difforder = 2;

if flags.do_normal
    fgrad = pderiv(logs,2,difforder)/size(logs,2);
elseif flags.do_causal
    fgrad = (circshift(logs,[0,2]) -4*circshift(logs,[0,1])+3*logs)/2;
end

% Undo the scaling done by pderiv and scale properly
tgrad = pderiv(logs,1,difforder)/size(logs,1);

% Fix the first and last rows .. the
% borders are symmetric so the centered difference is 0
tgrad(1,:) = 0;
tgrad(end,:) = 0;

tgrad = tgradmul(tgrad);
fgrad = fgradmul(fgrad);
usephase = zeros(M2,2);
tmpmask = zeros(M2,2);
tmpmask(:,1) = 1;
newphase = zeros(M2,N);
c = zeros(M2,N);

for n=1:N
    idx = mod( n-1-1:n-1, N ) + 1;   

    newphasetmp = comp_constructphasereal(abss(:,idx),tgrad(:,idx),fgrad(:,idx),a,M,tol,2,tmpmask,usephase);
    usephase(:,1) = newphasetmp(:,2);
    newphase(:,n) = usephase(:,1);
    
    % Build the coefficients
    c(:,n)=abss(:,n).*exp(1i*newphase(:,n));
end
