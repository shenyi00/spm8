function DCM = spm_dcm_ind(DCM)   
% Estimate parameters of a DCM model of spectral responses)
% FORMAT DCM = spm_dcm_ind(DCM)   
%
% DCM     
%    name: name string
%       M:  Forward model
%              M.dipfit - leadfield specification
%       xY: data   [1x1 struct]
%       xU: design [1x1 struct]
%
%   Sname: cell of source name strings
%       A: {[nr x nr double]  [nr x nr double]  [nr x nr double]}
%       B: {[nr x nr double], ...}   Connection constraints
%       C: [nr x 1 double]
%
%   options.Nmodes       - number of frequency modes
%   options.Tdcm         - [start end] time window in ms
%   options.D            - time bin decimation       (usually 1 or 2)
%   options.h            - number of DCT drift terms (usually 1 or 2)
%   options.type         - 'ECD' (1) or 'Imaging' (2) (see spm_erp_L)
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging
 
% Karl Friston
% $Id: spm_dcm_ind.m 2931 2009-03-24 10:33:19Z guillaume $


% check options 
%==========================================================================
clear spm_erp_L

% Filename and options
%--------------------------------------------------------------------------
try, DCM.name;                  catch, DCM.name           = 'DCM_IND'; end
try, DCM.options.Nmodes;        catch, DCM.options.Nmodes = 4;         end
try, h     = DCM.options.h;     catch, h                  = 1;         end
try, onset = DCM.options.onset; catch, onset              = 80;        end

% Data and spatial model
%==========================================================================
DCM    = spm_dcm_erp_dipfit(DCM, 1);

if ~isfield(DCM.xY, 'source')   
    DCM    = spm_dcm_ind_data(DCM);
end

xY     = DCM.xY;
xU     = DCM.xU;
xU.dt  = xY.dt;

% dimensions
%--------------------------------------------------------------------------
Nt     = length(xY.y);                  % number of trials
Nr     = size(DCM.C,1);                 % number of sources
nu     = size(DCM.C,2);                 % number of neuronal inputs
Nf     = size(xY.U,2);                  % number of frequency modes
Ns     = size(xY.y{1},1);               % number of samples
Nu     = size(xU.X,2);                  % number of trial-specific effects
nx     = Nr*Nf;                         % number of states


% assume noise precision is the same over modes:
%--------------------------------------------------------------------------
xY.Q   = {spm_Q(1/2,Ns,1)};
xY.X0  = sparse(Ns,0);

% Inputs
%==========================================================================

% trial-specific effects
%--------------------------------------------------------------------------
try
    if length(DCM.B) ~= Nu;
        warndlg({'please ensure number of trial specific effects', ...
                 'encoded by DCM.xU.X & DCM.B are the same'})
    end
catch
    DCM.B = {};
end

% model specification and nonlinear system identification
%==========================================================================
M      = DCM.M;
try, M = rmfield(M,'g');  end
try, M = rmfield(M,'FS'); end

% prior moments
%--------------------------------------------------------------------------
[pE,gE,pC,gC] = spm_ind_priors(DCM.A,DCM.B,DCM.C,Nf);


% likelihood model
%--------------------------------------------------------------------------
M.IS  = 'spm_gen_ind';
M.f   = 'spm_fx_ind';
M.G   = 'spm_lx_ind';
M.x   = sparse(nx,1);
M.pE  = pE;
M.pC  = pC;
M.gE  = gE;
M.gC  = gC;
M.m   = nu;
M.n   = nx;
M.l   = Nr*Nf;
M.ns  = Ns;
M.ons = onset - xY.pst(1);


% EM: inversion
%--------------------------------------------------------------------------
[Qp,Qg,Cp,Cg,Ce,F] = spm_nlsi_N(M,xU,xY);

% Bayesian inference {threshold = prior} NB Prior on A,B  and C = exp(0) = 1
%==========================================================================
warning('off','SPM:negativeVariance');
dp  = spm_vec(Qp) - spm_vec(pE);
Pp  = spm_unvec(1 - spm_Ncdf(0,abs(dp),diag(Cp)),Qp);
warning('on','SPM:negativeVariance');


% neuronal and sensor responses (x and y)
%--------------------------------------------------------------------------
L   = feval(M.G, Qg,M);           % get gain matrix
x   = feval(M.IS,Qp,M,xU);        % prediction (source space)

% trial-specific respsonses (in mode, channel and source space)
%--------------------------------------------------------------------------
for i = 1:Nt
    
    s  = x{i};                   % prediction (source space)
    y  = s*L';                   % prediction (sensor space)
    r  = xY.y{i} - y;            % residuals  (sensor space)
    
    % parse frequency modes
    %----------------------------------------------------------------------
    for j = 1:Nf
        f      = [1:Nr] + (j - 1)*Nr;
        H{i,j} = y(:,f);
        R{i,j} = r(:,f);
        K{i,j} = s(:,f);
    end
end

% store estimates in DCM
%--------------------------------------------------------------------------
DCM.M  = M;                    % model specification
DCM.xY = xY;                   % data structure
DCM.xU = xU;                   % input structure
DCM.Ep = Qp;                   % conditional expectation f(x,u,p)
DCM.Cp = Cp;                   % conditional covariances G(g)
DCM.Eg = Qg;                   % conditional expectation
DCM.Cg = Cg;                   % conditional covariances
DCM.Pp = Pp;                   % conditional probability
DCM.H  = H;                    % conditional responses (y), channel space
DCM.K  = K;                    % conditional responses (x)
DCM.R  = R;                    % conditional residuals (y), channel space
DCM.Ce = Ce;                   % ReML error covariance
DCM.F  = F;                    % Laplace log evidence


% and save
%--------------------------------------------------------------------------
if spm_matlab_version_chk('7.1') >= 0
    save(DCM.name, '-V6', 'DCM');
else
    save(DCM.name, 'DCM');
end
assignin('base','DCM',DCM)
return