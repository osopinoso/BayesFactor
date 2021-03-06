enumerateRegressionModels = function(fmla, whichModels, data){
  trms <- attr(terms(fmla, data = data), "term.labels")
  ntrms <- length(trms)
  dv = stringFromFormula(fmla[[2]])
  if(ntrms == 1 ) whichModels = "all"
  
  if(whichModels=="top"){
    lst = combn2( trms, ntrms - 1 )
  }else if(whichModels=="all"){
    lst = combn2( trms, 1 )
  }else if(whichModels=='bottom'){
    lst = as.list(combn( trms, 1 ))
  }else{
    stop("Unknown whichModels value: ",whichModels)
  }
  strng <- lapply(lst,function(el){
    paste(el,collapse=" + ")
  })
  fmla <- lapply(strng, function(el){
    formula(paste(dv,"~", el))
  })
  return(fmla)
}

createFullRegressionModel <- function(formula, data){
  factors = fmlaFactors(formula, data)[-1]
  
  dv = stringFromFormula(formula[[2]])
  
  RHS = paste(factors,collapse=" + ")
  strng = paste(dv, " ~ ", RHS, collapse = "")
  return(formula(strng))
}

integrand.regression=Vectorize(function(g, N, p , R2, rscaleSqr=1, log=FALSE, log.const=0){
  a = .5 * ((N - p - 1 ) * log(1 + g) - (N - 1) * log(1 + g * (1 - R2)))
  shape=.5
  scale=rscaleSqr*N/2
  log.density.igam <- dinvgamma1(g, shape, scale)
  ans = a + log.density.igam - log.const
  ifelse(log,ans,exp(ans))
},"g")

linearReg.Gibbs <- function(y, covariates, iterations = 10000, rscale = "medium", progress = options()$BFprogress, callback=function(...) as.integer(0), noSample=FALSE, ...){
  rscale = rpriorValues("regression",,rscale)
  X <- apply(covariates,2,function(v) v - mean(v))
  y = matrix(y,ncol=1)
  N = length(y)
  p = ncol(X)
  Cn = diag(N) - matrix(1,N,N)/N 
  XtX = t(X)%*%X
  XtCnX = t(X)%*%Cn%*%X
  XtCny = t(X)%*%Cn%*%y
  Cny = Cn%*%y
  
  sig2start = sum( (X%*%solve(XtCnX)%*%XtCny - Cny)^2 ) / N
  
  if(progress & !noSample){
    pb = txtProgressBar(min = 0, max = 100, style = 3) 
  }else{ 
    pb=NULL 
  }
  
  pbFun = function(samps){ 
    if(progress){
      percent = as.integer(round(samps / iterations * 100))
      setTxtProgressBar(pb, percent)
    }
  }
  
  if(noSample){
    chains = matrix(NA,ncol(covariates)+2,2)
  }else{
    chains = .Call("RGibbsLinearReg", 
                 as.integer(iterations), 
                 Cny,
                 X,
                 XtX,
                 XtCnX,
                 XtCny,
                 as.integer(N),
                 as.integer(p),
                 rscale,
                 sig2start,
                 progress,
                 pbFun,
                 callback,
                 new.env(),
                 package="BayesFactor")
  }
  if(inherits(pb,"txtProgressBar")) close(pb);
  chains = t(chains)
  
  colnames(chains) = c(colnames(covariates),"sig2","g")
  return(mcmc(chains))
  
}

