###############################################################
############## MARKOVITZ MEAN VARIANCE PORTFOLIO ##############
###############################################################

# Plotter for the efficient frontier
PlotEfficientFrontier = function(exp_returns, covariance, min_r=NA, max_r,  exclude = NA, add_no_short_sell = TRUE, full_plot = FALSE)
{
  N_assets = length(exp_returns)
  full_idx = 1:N_assets
  
  if (!is.na(exclude) ){
    if (max(exclude)<=N_assets && min(exclude)>0){
      idx = full_idx[-exclude]
      #print(idx)
    }
    else{
      warning("Wrong index format for excluded assets.")
      idx = full_idx
    }
  }
  else{
    idx = full_idx
  }
  
  total_result = list()
  
  # unconstrained = short sales are allowed for every asset
  res1 = EfficientFrontier(exp_returns,covariance, min_r = min_r,max_r = max_r,full = full_plot)
  res2 = EfficientFrontier(exp_returns[idx],covariance[idx,idx], min_r =min_r, max_r = max_r, full = full_plot)
  total_result[["simple"]]=res1
  total_result[["simple_excluded"]]=res2
  
  # if plot is not working exchange x11 command for window or vice-versa
  x11()
  #windows(width = 10,height = 8)
  y_lim = c(1.0, max_r)
  plot(res1$sigma,res1$expected_return, type = 'l',col='darkgreen', ylim = y_lim, xlab = "Volatility", ylab = "Returns")
  lines(res2$sigma,res2$expected_return, col = 'red')
  points(sqrt(diag(covariance)),exp_returns, pch='+', col = 'blue')
  text(sqrt(diag(covariance)),exp_returns, labels = colnames(my_returns[,2*(idx)]),pos = 3)
  grid()
  
  
  if(add_no_short_sell){
    # constrained = no short sales for given assets
    res_btc = EfficientFrontier(r=exp_returns, S=covariance, full = full_plot, N=100, no_short_sales =1:N_assets, max_r = max_r)
    res_no_btc = EfficientFrontier(r= exp_returns[idx], S=covariance[idx,idx],full = full_plot, N =200, no_short_sales = idx)
    
    total_result[["no_short"]]=res_btc
    total_result[["no_short_excluded"]]=res_no_btc
    
    lines(res_btc$sigma, res_btc$expected_return, col= 'green')
    lines(res_no_btc$sigma[2:201], res_no_btc$expected_return[2:201], col = 'orange')
    
    legend("topleft", legend = c("btc", "NO btc", "btc, NO short sale","NO btc, NO short sale"),
           col=c("darkgreen","red","green","orange"), lwd = 3, lty = c(1,1,1,1), cex=0.75, bg = 'white')
  }
  else {
    legend("topleft", legend = c("btc", "NO btc"),
           col=c("darkgreen","red"), lwd = 3, lty = c(1,1), cex=0.75, bg = 'white')
  }
  
  title(main = "Efficient Markowitz Mean Variance Frontier")
  
  total_result
}


# Simple wrapper for frontier
EfficientFrontier=function(r,S, no_short_sales=NA, N=100,full=FALSE,plot=FALSE,min_r=NA, max_r=NA){
  
  if (is.na(no_short_sales[1])){
    return(EfficientFrontier_unconstr(r=r,S=S,full=full,plot=plot, N=N, max_r = max_r, min_r=min_r))

  }
  else{
    return(EfficientFrontier_constr(r=r,S=S,full=full,plot=plot, N=N, no_short_sales = no_short_sales,
                                    min_r=min_r, max_r = max_r))
  }
}


#Simple wrapper for optimal allocation
OptimalAllocation=function(r,S, target_return = NA, sd = NA, no_short_sales=NA){
  if (is.na(no_short_sales[1])){
    return(OptimalAllocation_unconstr(r=r,S=S, target_return = target_return, sd=sd))
  }
  else{
    return(OptimalAllocation_constr(r=r,S=S, target_return = target_return,no_short_sales = no_short_sales))
    
  }
}



OptimalAllocation_unconstr= function(r,S, target_return = NA, sd = NA){
  
  if(is.na(target_return) & is.na(sd)){
    stop("Please specify expected return or standard deviation.")
  }
  
  invS = solve(S)
  e = matrix(rep(1,length(r)),nrow = length(r),ncol = 1) # unit vector
  
  a = drop(t(e)%*% invS %*% e)
  b = drop(t(e)%*% invS %*% r)
  c = drop(t(r)%*% invS %*% r)
  d = drop(a*c - b^2)
  
  
  if (!is.na(target_return)){
    mu = drop((a*target_return - b)/d)
    lambda = drop( (d - a*b*target_return + b^2)/(a*d))
    
    w_opt = invS %*% (e*lambda + mu*r)
    
    sigma_opt = sqrt(t(w_opt)%*%S%*%w_opt)
   
    sigma = sqrt( (a*target_return^2 - 2*b*target_return + c)/d)
    print(paste(sigma_opt, sigma))
    # test on the results:
    if (abs(sigma - sigma_opt) > 1e-6){
      stop("Computations of minimum standard deviation yield different results.")
    }
    
    print(paste("Minimum standard deviation for given expected return is", sigma_opt))
    
  }
  else if (!is.na(sd)){
    if(sd < sqrt(1/a)){
      stop("Impossible to obtain such a small risk with given assets.")
    }
    
    expected_return_opt =  (b+sqrt(b^2-a*(c-d*sd^2)))/a
    mu = drop((a*expected_return_opt - b)/d)
    lambda = drop( (d - a*b*expected_return_opt + b^2)/(a*d))
    
    w_opt = invS %*% (e*lambda + mu*r)
    
    sigma_opt = sqrt(t(w_opt)%*%S%*%w_opt)
    
    
    # test on the results:
    if (abs(sd - sigma_opt) > 1e-6){
      stop("Computation of minimum standard deviation yields a different result.")
    }
    print(paste("Maximum expected return for given standard deviation is",expected_return_opt))
  }
  
  return(w_opt)
}



OptimalAllocation_constr= function(r,S, target_return = NA, no_short_sales){
  
  if(is.na(target_return)){
    stop("Please specify expected return.")
  }

  if(target_return > max(r)){
    # print(max(r))
    warning("Cannot produce such a high return without short-selling.")
    target_return=max(r)-1e-5
  }
  
  library(quadprog)
  
  # number of assets
  n= length(r)
  
  D = 2*S       #times 2 because there is a 1/2 in the implicit formulation
  d = rep(0,n)  # zeros
  
  
  # Constraint on returns
  A = t(r)
  
  b = target_return
  
  # Constraint on weights: sum(w)=1
  A = rbind(A,rep(1,n))
  b= rbind(b,1)
  
  
  # Constraints on short selling ony on given assets
  for (i in no_short_sales){
    A_i = rep(0,n)
    A_i[i]=1
    A = rbind(A,A_i)
    b = rbind(b,0)
  }
  
  sol = solve.QP(Dmat = D, dvec = (d), Amat = t(A), bvec = t(b), meq = 2)
  w_opt= sol$solution
  rownames(w_opt)=rownames(r)
  return(w_opt)
}





EfficientFrontier_unconstr = function(r,S,full=FALSE,plot=FALSE, N=100, max_r=NA, min_r=NA){
  # INPUT
  # r: expected returns of the assets
  # S: covariance matrix of the asset returns
  # full: computes only upper section of frontier if FALSE
  # plot: if TRUE the frontier is plotted
  # N: how many expected returns to take into consideration to plot frontier
  if (is.na(max_r)){
    max_r = max(r)
  }
  if (is.na(min_r)){
    min_r = min(r)
  }

  invS = solve(S)
  e = matrix(rep(1,length(r)),nrow = length(r),ncol = 1) # unit vector

  a = drop(t(e)%*% invS %*% e)
  b = drop(t(e)%*% invS %*% r)
  c = drop(t(r)%*% invS %*% r)
  d = drop(a*c - b^2)
  
  
  yy= seq(from = min_r, to = max_r,length.out = N+1)
  xx = sqrt( (a*yy^2 - 2*b*yy + c)/d)

  if (!full){
    min_sigma = min(xx)
    idx = which(yy>=yy[which(xx==min_sigma)])
    # print(idx)
    xx= xx[idx]
    yy= yy[idx]
  }

  if(plot){
    min_y = min(c(yy,r))
    max_y = max(c(yy,r))
    plot(xx,yy,type ='l', ylim = c(min_y,max_y))
    points(sqrt(diag(S)),r,col='blue',pch='+')
    #legend(c("Efficient Frontier","Single Assets"))
  }
  res = list(sigma = xx, expected_return=yy)
  return(res)
}





EfficientFrontier_constr = function(r,S,full=FALSE,plot=FALSE, N=100, no_short_sales, max_r=NA, min_r =NA){
  # INPUT
  # r: expected returns of the assets
  # S: covariance matrix of the asset returns
  # full: computes only upper section of frontier if FALSE
  # plot: if TRUE the frontier is plotted
  # N: how many expected returns to take into consideration to plot frontier

  library(quadprog)
  
  if (is.na(max_r)){
    max_r = max(r)
  }
  if (is.na(min_r)){
    min_r = min(r)
  }
  
  # number of assets
  n= length(r)

  D = 2*S       #times 2 because there is a 1/2 in the implicit formulation
  d = rep(0,n)  # zeros
  
  
  # Constraint on returns
  A = t(r)
  
  b = 0.0 # expected return that will be iterated to compute frontier
  
  # Constraint on weights: sum(w)=1
  A = rbind(A,rep(1,n))
  b= rbind(b,1)
  
  
  # Constraint on short selling on given assets
  for (i in no_short_sales){
    A_i = rep(0,n)
    A_i[i]=1
    A = rbind(A,A_i)
    b = rbind(b,0)
  }

  # yy = set of returns
  # xx = set of corresponding volatility
  yy= seq(from = min(r), to = max_r,length.out = N+1)
  yy[1] = yy[1]+ 1e-5
  yy[N+1] = yy[N+1] -1e-5
  
  b[1]= yy[1]
  # print(yy)
  
  xx = rep(0,length(yy))
  for (i in 1:(N+1)) {
    # print(i)
    # print(yy[i])
    b[1] = yy[i]
    # print(b)
    sol = solve.QP(Dmat = D, dvec = (d), Amat = t(A), bvec = t(b), meq = 2)
    xx[i] = sqrt(sol$value)
    
    # sigma = sqrt(t(sol$solution)%*%SS%*%sol$solution)
    # print(paste(xx[i], sigma))
  }

  if (!full){
    min_sigma = min(xx)
    # print(min_sigma)
    idx = which(yy>=yy[which(xx==min_sigma)])
    # print(idx)
    xx= xx[idx]
    yy= yy[idx]
  }

  # if(plot){
  #   min_y = min(c(yy,r))
  #   max_y = max(c(yy,r))
  #   plot(xx,yy,type ='l', ylim = c(min_y,max_y))
  #   points(sqrt(diag(S)),r,col='blue',pch='+')
  #   #legend(c("Efficient Frontier","Single Assets"))
  # }
  res = list(sigma = xx, expected_return=yy)
  return(res)
}
