# PORTFOLIO VaR OPTIMIZATION 

OptimalAllocationVaR = function(simulated_returns, alpha, target_return, N_rep=10, CVaR =  FALSE){
  library(alabama)
  if(CVaR){
    objective = ptf_cvar
  }
  else{
    objective = ptf_var
  }
  # simulated_returns should be given as a matrix (N_sim * N_assets)
  N_assets = dim(simulated_returns)[2]
  
  expected_asset_return = colMeans(simulated_returns)
  solution = list(obj = rep(0,N_rep), params = matrix(rep(0,N_rep*N_assets),ncol = N_assets), expected_ret=rep(0,N_rep))
  for (i in 1:N_rep) {
    # creating initial weights summing to one
    sampled =  runif(N_assets)
    rand_initial = sampled/sum(sampled)
    
    res = auglag(par = rand_initial, fn=objective, hin = f_ineq, heq =f_eq,
                 sims=simulated_returns, alpha = alpha, target_return = target_return,
                 control.outer = list( trace = FALSE))
    solution$obj[i]=res$value
    solution$params[i,]=matrix(res$par,ncol = N_assets)
    solution$expected_ret[i]=(sum(res$par*expected_asset_return))
    print(paste("Target return:", target_return, "Iteration:", i, "Objective:", res$value))
  }
  # print(solution)
  idx = which.min(solution$obj)
  
  return(list(objective = solution$obj[idx], 
              allocation = solution$params[idx,],
              expected_return = solution$expected_ret[idx]))
  
}



ptf_var = function(w,  sims, alpha, target_return){
  loss_annual = 1-sims%*%w
  VaR = quantile(x = loss_annual, probs = 1-alpha)
  return(VaR)
}

ptf_cvar = function(w,  sims, alpha, target_return){
  loss_annual = 1-sims%*%w
  sorted_loss = sort(loss_annual,decreasing = FALSE)
  VaR = quantile(x = loss_annual, probs = 1-alpha)
  idx_var = min(which(sorted_loss >= VaR))
  # print(idx_var)
  CVaR = mean(sorted_loss[idx_var:length(sorted_loss)])
  return(CVaR)
}


f_eq = function(w, sims, alpha,target_return){
  # weights should sum to 1
  c1 = sum(w)-1 
  N_s = dim(sims)[1]
  # expected return should be the same as target_return
  c3 = sum(t(sims)%*% matrix(rep(1, N_s),ncol = 1) *w) /N_s - target_return
  
  return(c(c1, c3))
}


f_ineq = function(w, sims, alpha,target_return){
  # no short-selling, so all weigths should be positive
  return(w)
}


ptf_var_w_constr= function(w, sims, alpha,target_return){
  toll = 1e-7
  N_s = dim(sims)[1]
  if ( sum(t(sims)%*% rep(1, N_s)*w) /N_s - target_return < 0 ){
    return(10)
  }
  else if(sum(w)>1+toll || sum(w)<1-0.001){
    return(10)
  }
  else {
    annual = sims%*%w
    res = quantile(x = 1-annual, probs = 1-alpha)
    return(res)
  }
}




OptimalAllocationDailyVaR= function(daily_return, alpha, target_return, N_rep=10){
  # daily_return are the daily return of last 5 years as a matrix(N_days * N_assets)
  N_assets = dim(daily_return)[2]
  
  expected_asset_return = colMeans(daily_return)

  solution = list(obj = rep(0,N_rep), params = matrix(rep(0,N_rep*N_assets),ncol = N_assets), expected_ret=rep(0,N_rep))
  
  for (i in 1:N_rep) {
    #creating initial weights summing to one
    sampled =  runif(N_assets)
    rand_initial = sampled/sum(sampled)
    
    res = auglag(par = rand_initial, fn=daily_ptf_cvar, hin = f_ineq_daily, heq =f_eq_daily,
                 sims=daily_return, alpha = alpha, target_return = target_return,
                 control.outer = list(method = "nlminb", trace = FALSE))
    solution$obj[i]=res$value
    solution$params[i,]=matrix(res$par,ncol = N_assets)
    solution$expected_ret[i]=(sum(res$par*expected_asset_return))
    # print(paste("CVaR:", daily_ptf_cvar(w=rand_initial, daily_return = daily_return, alpha = alpha, target_return = target_return),
    #             "expected return:", sum(rand_initial*expected_asset_return)))
    print(paste("Target return:", target_return, "Iteration:", i))
  }
  
  # print(solution)
  idx = which.min(solution$obj)
  
  return(list(objective = solution$obj[idx], 
              allocation = solution$params[idx,],
              expected_return = solution$expected_ret[idx]))
}



daily_ptf_var = function(w, sims, alpha, target_return){
  daily_loss = 1 - sims%*%w
  return(quantile(x = daily_loss, probs = 1-alpha))
}


daily_ptf_cvar = function(w,  sims, alpha, target_return){
  daily_loss = 1 - sims%*%w
  sorted_loss = sort(daily_loss,decreasing = FALSE)
  VaR = quantile(x = daily_loss, probs = 1-alpha)
  idx_var = min(which(sorted_loss >= VaR))
  # print(idx_var)
  CVaR = mean(sorted_loss[idx_var:length(sorted_loss)])
  return(CVaR)
}


f_eq_daily = function(w, sims, alpha,target_return){
  # weights should sum to 1
  c1 = sum(w)-1 
  
  N_s = dim(sims)[1]
  # expected return should be the same as target_return
  c3 =  sum(t(sims)%*% matrix(rep(1, N_s),ncol = 1) *w) /N_s - target_return
  return(c(c1, c3))
}

f_ineq_daily = function(w, sims, alpha,target_return){
  # no short-selling, so all weigths should be positive
  return(w)
}
