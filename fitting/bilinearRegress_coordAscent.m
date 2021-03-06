function [w_hat,wt,wx] = bilinearRegress_coordAscent(xx,xy,wDims,rnk,lambda,opts)
% [w_hat,wcols,wrows] = bilinearRegress_coordAscent(xx,xy,wDims,rnk,opts)
% 
% Computes linear regression estimate with a bilinear parametrization of the parameter vector.  
%
% Finds solution to argmin_w ||y - x*w||^2 + lambda*||w||^2
% where w are parametrized as vec( wt*wx')
%
% Inputs:
% -------
%   xx - autocorrelation of design matrix (unnormalized)
%   xy - crosscorrelation between design matrix and dependent var (unnormalized)
%   wDims - [nt, nx] two-vector specifying # rows & # cols of w.
%   p - rank of bilinear filter
%   lambda - ridge parameter (optional)
%   opts - options struct (optional)
%          fields: 'MaxIter' [25], 'TolFun' [1e-6], 'Display' ['iter'|'off']
%
% Outputs:
% -------
%   wHat = estimate of full param vector
%   wt = column vectors
%   wx = row vectors

if (nargin >= 5) && ~isempty(lambda)  
    xx = xx + lambda*eye(size(xx)); % add ridge penalty to xx
end

if (nargin < 6) || isempty(opts)
    opts.MaxIter = 25;
    opts.TolFun = 1e-6;
    opts.Display = 'iter';
end

% Set some params
nt = wDims(1);
nx = wDims(2);
It = speye(nt);
Ix = speye(nx);

% Initialize estimate of w by linear regression and SVD
w0 = xx\xy;
[wt,s,wx] = svd(reshape(w0,nt,nx));
wt = wt(:,1:rnk)*sqrt(s(1:rnk,1:rnk));
wx = sqrt(s(1:rnk,1:rnk))*wx(:,1:rnk)';

% Start coordinate ascent
w = vec(wt*wx);
fval = .5*w'*xx*w - w'*xy;
fchange = inf;
iter = 1;
if strcmp(opts.Display, 'iter')
    fprintf('--- Coordinate descent of bilinear loss ---\n');
    fprintf('Iter 0: fval = %.4f\n',fval);
end

while (iter <= opts.MaxIter) && (fchange > opts.TolFun)
    
    % Update temporal components
    Mx = kron(wx',It);
    wt = (Mx'*xx*Mx)\(Mx'*xy);
    wt = reshape(wt, nt,rnk);
    
    % Update spatial components
    Mt = kron(Ix, wt);
    wx = (Mt'*xx*Mt)\(Mt'*xy);
    wx = reshape(wx,rnk,nx);

    % Compute size of change 
    w = vec(wt*wx);
    fvalnew = .5*w'*xx*w - w'*xy;
    fchange = fval-fvalnew;
    fval = fvalnew;
    iter = iter+1;
    if strcmp(opts.Display, 'iter')
	fprintf('Iter %d: fval = %.4f,  fchange = %.4f\n',iter-1,fval,fchange);
    end
end

w_hat = wt*wx;