function [wt,wx,wvec] = bilinearMultifiltRegress_coordAscent(xx,xy,nt,nx,rnk,lambda,opts)
% wstruct = bilinearMultifiltRegress_coordAscent(xx,xy,nt,nx,rnk,indsbilin,lambda,opts)
% 
% Computes regression estimate with a bilinear parametrization of part of
% the parameter vector.
%
% Finds solution to argmin_w ||y - x*w||^2 + lambda*||w||^2
% where part of w is parametrized as vec(wt*wx')
%
% Inputs:
% -------
%   xx - autocorrelation of design matrix (unnormalized)
%   xy - crosscorrelation between design matrix and dependent var (unnormalized)
%   nt - # of rows of each weight matrix
%   nx - # of columns of each weight matrix
%   rnk - rank of bilinear filter
%   lambda - ridge parameter (optional)
%   opts - options struct (optional)
%          fields: 'MaxIter' [25], 'TolFun' [1e-6], 'Display' ['iter'|'off']
%
% Outputs:
% -------
%   wstruct  = vector of structures with fields:
%     .wt = column vectors 
%     .wx = row vectors 
%     .wfilt = wt*wx';
%   wvec = full vector of regression weights

% ----------------------------------
% set optimization options
if (nargin < 7) || isempty(opts)
    opts.default = true;
end
if ~isfield(opts, 'MaxIter'); opts.MaxIter = 25; end
if ~isfield(opts, 'TolFun'); opts.TolFun = 1e-6; end
if ~isfield(opts, 'Display'); opts.Display = 'iter'; end

% ----------------------------------
% add ridge penalty to diagonal of xx
if (nargin >= 6) && ~isempty(lambda)  
    xx = xx + lambda*eye(size(xx)); 
end

% -----------------------------------
% Set some size params and build needed indices & sparse matrices
nfilts = length(nt); % number of filters
nwtot = length(xy);  % number of total filter coeffs
nw = zeros(nfilts,1); % number of coeffs in each filter
nwt = zeros(nfilts,1); % number of low rank column vector params
nwx = zeros(nfilts,1); % number of low rank row vector params
ntcll = num2cell(nt(:));   % length of col vectors (as cell array)
nxcll = num2cell(nx(:));   % length of row vectors (as cell array)
rnkcll = num2cell(rnk(:)); % filter ranks (as cell array)

% Calculate sizes 
icum = 0;
inds = cell(nfilts,1);
It = cell(nfilts,1);
Ix = cell(nfilts,1);
for jj = 1:nfilts
    nw(jj) = nt(jj)*nx(jj);  % number of filter coeffs in each filter
    nwt(jj) = rnk(jj)*nt(jj); % number of params in column vectors
    nwx(jj) = rnk(jj)*nx(jj); % number of params in row vectors

    % set indices for these coeffs
    inds{jj} = icum+1:icum+nw(jj);
    icum = icum+nw(jj);
    
    % build needed sparse matrices
    It{jj} = speye(nt(jj));
    Ix{jj} = speye(nx(jj));

end

% -----------------------------------
% Initialize estimate of w by linear regression and SVD
w0 = xx\xy;
wstruct = struct;
wt = cell(nfilts,1);
wx = cell(nfilts,1);

% do SVD on each relevant portion of w0
for jj = 1:nfilts
    [wt0,s,wx0] = svd(reshape(w0(inds{jj}),nt(jj),nx(jj))); % SVD
    wt{jj} = wt0(:,1:rnk(jj))*sqrt(s(1:rnk(jj),1:rnk(jj)));  % column vecs
    wx{jj} = sqrt(s(1:rnk(jj),1:rnk(jj)))*wx0(:,1:rnk(jj))'; % row vecs

end

% -----------------------------------
% Initialize coordinate ascent

% define useful function: vectorize after matrix multiply
vecMatMult = @(x,y)(vec(mtimes(x,y))); 

% Compute full weight vector from its low-rank components
wvec = cellfun(vecMatMult,wt,wx,'UniformOutput',false); % full weights in cell array
wvec = cell2mat(wvec); % convert to vector

% Evaluate loss function for initial weights
fval = .5*wvec'*xx*wvec - wvec'*xy;
fchange = inf;
iter = 1;

if strcmp(opts.Display, 'iter')
    fprintf('--- Coordinate descent of bilinear loss ---\n');
    fprintf('Iter 0: fval = %.4f\n',fval);
end

% define useful function: compute kronecker of transpose with matrix
kronTrp = @(v,A)(kron(v',A)); 

% -----------------------------------
% Run coordinate ascent

while (iter <= opts.MaxIter) && (fchange > opts.TolFun)
    
    % ===========================
    % Update temporal components
    Mx = cellfun(kronTrp,wx,It,'UniformOutput',false); % cell array of kronecker matrices
    Mx = blkdiag(Mx{:});  % convert to block-diagonal matrix
    wtnew = (Mx'*xx*Mx)\(Mx'*xy);  % new temporal weights as column vector
    
    % Store temporal weights in cell array
    wtnew = mat2cell(wtnew,nwt,1);  % break into cell array of vectors
    wt = cellfun(@reshape,wtnew,ntcll,rnkcll,'UniformOutput',false); % reshape into appropriate columns
    
    % ===========================
    % Update spatial components
    Mt = cellfun(@kron,Ix,wt,'UniformOutput',false); % cell array of kronecker matrices
    Mt = blkdiag(Mt{:});  % convert to block-diagonal matrix
    wxnew = (Mt'*xx*Mt)\(Mt'*xy); % new spatial weights as column vector
    
    % Store spatial weights in cell array    
    wxnew = mat2cell(wxnew,nwx,1);  % break into cell array of vectors
    wx = cellfun(@reshape,wxnew,rnkcll,nxcll,'UniformOutput',false); % reshape into appropriate columns
    
    % Compute full weight vector from its low-rank components
    wvec = cellfun(vecMatMult,wt,wx,'UniformOutput',false); % full weights in cell array
    wvec = cell2mat(wvec); % convert to vector
    
    % Evaluate loss function & size of change
    fvalnew = .5*wvec'*xx*wvec - wvec'*xy;
    fchange = fval-fvalnew;
    fval = fvalnew;
    iter = iter+1;
    if strcmp(opts.Display, 'iter')
        fprintf('Iter %d: fval = %.4f,  fchange = %.4f\n',iter-1,fval,fchange);
    end
end

