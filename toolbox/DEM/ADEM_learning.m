% Value learning demo using the mountain car problem. This demo questions
% the need for reinforcement learning and related paradigms from
% machine-learning, when trying to optimise the behaviour of an agent.  We
% show that it is fairly simple to teach an agent complicated and adaptive
% behaviours under the free-energy principle.  This principle suggests that
% agents adjust their internal states and sampling of the environment to
% minimize their free-energy.  In this context, free-energy represents a
% bound on the probability of being in a particular state, given the nature
% of the agent, or more specifically the model of the environment an agent
% entails.  We show that such agents learn causal structure in the
% environment and sample it in an adaptive and self-supervised fashion.
% The result is a behavioural policy that reproduces exactly the policies
% that are optimised by reinforcement learning and dynamic programming.
% Critically, at no point do we need to invoke the notion of reward, value
% or utility.  We illustrate these points by solving a benchmark problem in
% dynamic programming; namely the mountain-car problem using just the
% free-energy principle.  The ensuing proof of concept is important because
% the free-energy formulation also provides a principled account of
% perceptual inference in the brain and furnishes a unified framework for
% action and perception.
 
 
% generative model
%==========================================================================
clear
DEMO     = 0;                          % switch for demo
G(1).E.s = 1/4;                        % smoothness
G(1).E.n = 6;                          % smoothness
G(1).E.d = 2;                          % smoothness
 
% parameters
%--------------------------------------------------------------------------
P.a     = 0;
P.b     = [0 0];
P.c     = [0 0 0 0];
P.d     = 0;
P0      = P;
pC      = speye(length(spm_vec(P)));
pC(end) = 0;
 
% level 1
%--------------------------------------------------------------------------
G(1).x  = [0; 0];
G(1).f  = 'spm_fx_mountaincar';
G(1).g  = inline('x','x','v','a','P');
G(1).pE = P;
G(1).pC = pC;
G(1).V  = exp(8);                           % error precision
G(1).W  = diag([exp(16) exp(6)]);           % error precision
 
% level 2
%--------------------------------------------------------------------------
G(2).a  = 0;                                % action
G(2).v  = 0;                                % inputs
G(2).V  = exp(16);
G       = spm_ADEM_M_set(G);
 
 
% desired equilibrium density and state space
%==========================================================================
G(1).fq = 'spm_mountaincar_Q';
 
% create X - coordinates of evaluation grid
%--------------------------------------------------------------------------
nx      = 32;
x{1}    = linspace(-1,1,nx);
x{2}    = linspace(-1,1,nx);
[X x]   = spm_ndgrid(x);
G(1).X  = X;
 
 
% optimise parameters so that p(y|G) maximises the cost function
%==========================================================================
 
% optimise parameters: (NB an alternative is P = spm_fp_fmin(G));
%--------------------------------------------------------------------------
if DEMO
    P       = spm_fmin('spm_mountaincar_fun',P,pC,G);
    P.d     = 0;
    G(1).pE = P;
    disp(P)
    save mountaincar_model G
end
 
 
% or load previously optimised environment
%--------------------------------------------------------------------------
load mountaincar_model
P        = G(1).pE;
 
% plot flow fields and nullclines
%==========================================================================
spm_figure('GetWin','Graphics');
 
nx    = 64;
x{1}  = linspace(-2,2,nx);
x{2}  = linspace(-2,2,nx);
M     = G;
 
% uncontrolled flow (P0)
%--------------------------------------------------------------------------
M(1).pE = P0;
subplot(3,2,1)
spm_fp_display_density(M,x);
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('flow and equilibrium density','Fontsize',16)
 
subplot(3,2,2)
spm_fp_display_nullclines(M,x);
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('nullclines','Fontsize',16)
 
% controlled flow (P0)
%--------------------------------------------------------------------------
M(1).pE = P;
subplot(3,2,3)
spm_fp_display_density(M,x);
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('controlled','Fontsize',16)
 
subplot(3,2,4)
spm_fp_display_nullclines(M,x);
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('controlled','Fontsize',16)
drawnow
 
 
 
% recognition model: learn the controlled environmental dynamics
%==========================================================================
M       = G;
M(1).g  = inline('x','x','v','P');
 
% make a niave model (M)
%--------------------------------------------------------------------------
M(1).pE = P0;
M(1).pC = G(1).pC*exp(8);
M(1).V  = [];
M(1).W  = [];
M(1).Q  = speye(2);
M(1).R  = {diag([1 0]) diag([0 1])};
 
% teach naive model by exposing it to a controlled environment (G)
%--------------------------------------------------------------------------
clear DEM
 
% perturbations
%--------------------------------------------------------------------------
n     = 16;
i     = [1:n]*32;
C     = sparse(1,i,-randn(1,n)*4);
C     = spm_conv(C,2);
 
DEM.M = M;
DEM.G = G;
DEM.C = C;
DEM.U = C;
 
% optimise recognition model
%--------------------------------------------------------------------------
if DEMO
    DEM.M(1).E.nE = 16;
    DEM           = spm_ADEM(DEM);
    save mountaincar_model G DEM
end
 
load mountaincar_model
spm_figure('GetWin','DEM');

spm_DEM_qP(DEM.qP,DEM.pP)
spm_DEM_qU(DEM.qU)
 
 
 
% replace priors with learned conditional expectation
%--------------------------------------------------------------------------
spm_figure('GetWin','Graphics');
 
qP.P{1} = DEM.qP.P{1};
M(1).pE = qP.P{1};
M(1).pC = [];
try
    M = rmfield(M,'Q');
    M = rmfield(M,'R');
end
M(1).V  = G(1).V;
M(1).W  = G(1).W;
 
 
subplot(3,2,5)
spm_fp_display_density(M,x);
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('learnt','Fontsize',16)
 
subplot(3,2,6)
spm_fp_display_nullclines(M,x);
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('learnt','Fontsize',16)
 
 
 
% evaluate performance under active inference
%==========================================================================
 
% create uncontrolled environment (with action)
%--------------------------------------------------------------------------
A         = G;
A(1).pE   = P0;
A(1).pE.d = 1;
 
% make the recognition model confident about its predictions
%--------------------------------------------------------------------------
M(1).W    = exp(8);
M(1).V    = exp(8);
M(2).V    = exp(16);
A(1).W    = exp(16);
A(1).V    = exp(16);

% create DEM structure
%--------------------------------------------------------------------------
clear DEM
N       = 128;
U       = sparse(1,N);
C       = spm_conv(randn(1,N),8)/4;
DEM.G   = A;
DEM.M   = M;
DEM.C   = U;
DEM.U   = U;
DEM     = spm_ADEM(DEM);
 
% overlay true values
%--------------------------------------------------------------------------
spm_figure('GetWin','DEM');
spm_DEM_qU(DEM.qU,DEM.pU)
 
subplot(2,2,3)
spm_fp_display_nullclines(M,x);hold on
plot(DEM.pU.v{1}(1,:),DEM.pU.v{1}(2,:),'b'), hold off
xlabel('position','Fontsize',12)
ylabel('velocity','Fontsize',12)
title('learnt','Fontsize',16)


spm_figure('GetWin','FMIN');
clf, subplot(3,1,2)
drawnow
spm_mountaincar_movie(DEM)
title('click car for movie','FontSize',16)


