


#number of deaths between age x and x+t
dxt <- function(object, x, t, decrement) {
  #checks
  out <- numeric(1)
  if (!(class(object) %in% c("lifetable","actuarialtable","mdt")))
    stop("Error! Only lifetable, actuarialtable or mdt classes are accepted")
  if (missing(x))
    stop("Error! Missing x")
  if (missing(t))
    t = 1
  omega = getOmega(object) #prima object+1
  if (class(object) == "mdt") {
    #call specific function for MDT class
    if (!missing(decrement))
      out <-
        .dxt.mdt(
          object = object, x = x, time = t, decrement = decrement
        )
    else
      out <- .dxt.mdt(object = object, x = x, time = t)
  } else {
    #		if(missing(x)) stop("Error! Missing x")
    #		if(missing(t)) t=1
    #		omega=getOmega(object) #prima object+1
    #check if fractional
    if ((t %% 1) == 0) {
      lx = object@lx[which(object@x == x)]
      if ((x + t) > omega)
        out = lx
      else
        #before >=
        out = lx - object@lx[which(object@x == t + x)]
    } else {
      fracPart <- (t %% 1)
      intPart <- t - fracPart
      out <-
        dxt(object = object, x = x, t = intPart) + fracPart * dxt(object = object, x =
                                                                    x + intPart, t = 1)
    }
  }
  return(out)
}

#survival probability between age x and x+t
pxtvect <- function(object, x, t, fractional = "linear", decrement)
{
  #checks
  if (!(class(object) %in% c("lifetable","actuarialtable","mdt")))
    stop("Error! Only lifetable, actuarialtable or mdt classes are accepted")
  
  fractional <- testfractionnalarg(fractional)
  
  #class(object) %in% c("lifetable","actuarialtable") 
  if (missing(x))
    stop("Missing x")
  if (any(x < 0, t < 0))
    stop("Check x or t domain")
  if (missing(t))
    t = 1 #default 1
  if(length(x) <= 0)
    stop("x is of length zero")
  if(length(t) <= 0)
    stop("t is of length zero")
  
  n <- max(length(t), length(x))
  if(length(t) != length(x))
  {
    if(length(t) > 1 && length(x) > 1)
      warnings("t and x arguments have been recycled to match the maximum length of x and t")
    t <- rep(t, length.out=n)
    x <- rep(x, length.out=n)
  }
  
  #adjustment when age x is not an integer 
  y <- x - floor(x)
  t <- t+y
  
  #local lifetable data closed at maximum age
  omega <- getOmega(object)
  mylx <- c(object@lx, 0)
  names(mylx) <- paste0("x", c(object@x, omega+1))
  
  #retrieve l_floor(x) and l_floor(x+t)
  idx_shift <- 2 - object@x[1] #typically 2 when first age is 0
  l_floorx <- mylx[paste0("x", floor(x))]
  l_floorxp1 <- mylx[paste0("x", ceiling(x))]
  l_floorxt <- mylx[paste0("x", floor(x+t))]
  l_floorxtp1 <- mylx[paste0("x", ceiling(x+t))]
    
  #compute one-year survival probabilites 
  floort_p_floorx <- l_floorxt / l_floorx 
  ceilt_p_floorx <- l_floorxtp1 / l_floorx
  one_p_floorxt <- l_floorxtp1 / l_floorxt 
  one_p_floorx <- l_floorxp1 / l_floorx 
  
  #may contains NA if x or x+t is above omega => set to 0
  floort_p_floorx[is.na(floort_p_floorx)] <- 0 
  ceilt_p_floorx[is.na(ceilt_p_floorx)] <- 0 
  one_p_floorxt[is.na(one_p_floorxt)] <- 0
  one_p_floorx[is.na(one_p_floorx)] <- 0
  
  #adjustment when t is not integer
  z <- t - floor(t)
  
  if (fractional == "linear") {
    t_p_floorx <- z * ceilt_p_floorx + (1 - z) * floort_p_floorx
  } else if (fractional == "constant force") {
    t_p_floorx <- floort_p_floorx * one_p_floorxt^z 
  } else if (fractional == "hyperbolic") {
    t_p_floorx <- floort_p_floorx * one_p_floorxt / (1 - (1-z)*(1-one_p_floorxt))
  }
  
  #adjustment when age x is not an integer 
  y <- x - floor(x)
  if (fractional == "linear") {
    y_p_floorx <-  1 - y * (1-one_p_floorx)
  } else if (fractional == "constant force") {
    y_p_floorx <- one_p_floorx^y 
  } else if (fractional == "hyperbolic") {
    y_p_floorx <- one_p_floorx / (1 - (1-y)*(1-one_p_floorx))
  }
  
  as.numeric(t_p_floorx / y_p_floorx)
}

#survival probability between age x and x+t
pxt <- function(object, x, t, fractional = "linear", decrement)
{
  out <- NULL
  #checks
  if (!(class(object) %in% c("lifetable","actuarialtable","mdt")))
    stop("Error! Only lifetable, actuarialtable or mdt classes are accepted")
  
  fractional <- testfractionnalarg(fractional)
  
  if (class(object) == "mdt") {
    #specific function for multiple decrements
    out <-
      ifelse(
        missing(decrement), 1 - .qxt.mdt(object = object,x = x,t = t),
        1 - .qxt.mdt(object = object,x = x,t = t,decrement = decrement)
      )
    return(out)
  }
  
  #class(object) %in% c("lifetable","actuarialtable") 
  if (missing(x))
    stop("Missing x")
  if (any(x < 0, t < 0))
    stop("Check x or t domain")
  if (missing(t))
    t = 1 #default 1
  omega = getOmega(object)
  #if the starting age is fractional apply probability laws
  if ((x - floor(x)) > 0) {
    integerAge = floor(x)
    excess = x - floor(x)
    out = pxt(
      object = object, x = integerAge, t = excess + t, decrement = decrement
    ) / pxt(
      object = object, x = integerAge,t = excess, decrement = decrement
    )
    return(out)
  }
  #Rosa Corrales Patch
 # if ((object@lx[omega] > 0) &&
  #    (x + t) == (omega + 1)) {
  #  out <- 1 / object@lx[which(object@x == x)]
  #} else {
    #before x+t>=omega
    if ((x + t) >= omega + 1)
      return(0)

  if((x + t) > omega){ # x + t is between last lx > 0 and 0

    z <- t %% 1 #the fraction of year
    #linearly interpolates if fractional age
    pl <-
      object@lx[which(object@x == floor(t + x))] / object@lx[which(object@x ==
                                                                     x)] # Kevin Owens: fix on this line, moving it out of the linear if statement so it can be used in other assumptions
    if (fractional == "linear") {
      ph <- 0
      out <- z * ph + (1 - z) * pl
    } else if (fractional == "constant force") {
      out <- pl * pxt(object = object, x = (x + floor(t)),t = 1) ^ z # fix on this line
    } else if (fractional == "hyperbolic") {
      out <-
        pl * pxt(object = object, x = (x + floor(t)),t = 1) / (1 - (1 - z) * qxt(
          object = object, x = (x + floor(t)),t = 1
        )) # Kevin Owens: fix on this line
    }
  }
  else # x + t is less that or equal to omega
    #fractional ages
  {
    if ((t %% 1) == 0)
      out <-
        object@lx[which(object@x == t + x)] / object@lx[which(object@x == x)]
    else {
      z <- t %% 1 #the fraction of year
      #linearly interpolates if fractional age
      pl <-
        object@lx[which(object@x == floor(t + x))] / object@lx[which(object@x ==
                                                                       x)] # Kevin Owens: fix on this line, moving it out of the linear if statement so it can be used in other assumptions
      if (fractional == "linear") {
        ph <-
          object@lx[which(object@x == ceiling(t + x))] / object@lx[which(object@x ==
                                                                           x)]
        out <- z * ph + (1 - z) * pl
      } else if (fractional == "constant force") {
        out <- pl * pxt(object = object, x = (x + floor(t)),t = 1) ^ z # fix on this line
      } else if (fractional == "hyperbolic") {
        out <-
          pl * pxt(object = object, x = (x + floor(t)),t = 1) / (1 - (1 - z) * qxt(
            object = object, x = (x + floor(t)),t = 1
          )) # Kevin Owens: fix on this line
      }
    }
  }

  #  }
  return(out)
}


.forceOfMortality<-function(object,x)
{
	out<-NULL
	#checks
	if(!is(object, "lifetable")) stop("Error! Need lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	#force of mortality
	out<-log(pxt(object=object, x=x, t=1))
	return(out)
}

#the number of person-years lived between exact ages x and x+1
Lxt<-function(object, x,t=1,fxt=0.5)
{

	out<-NULL
	#checks

	if(!is(object, "lifetable")) stop("Error! Need lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	if(any(x<0,t<0)) stop("Check x or t domain")

	ages=seq(from=x, to=x+t-1, by=1)
	lifes=numeric(length(ages))
	for(i in 1:length(ages)) lifes[i]=object@lx[which(object@x==ages[i])]
	deaths=sapply(ages, dxt,object=object,t=1)
	toSum=lifes-fxt*deaths
	out=sum(toSum)
	return(out)
}
# the number of person-years lived after exact age x
Tx<-function(object,x)
{
	out<-NULL
 	#checks
	if(!is(object, "lifetable")) 
	  stop("Error! Need lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	n=getOmega(object)-x
	lives=seq(from=x,to=x+n,by=1)
	toSum<-sapply(lives, Lxt,object=object, t=1)
	return(sum(toSum))
}

#central mortality rate
mxt<-function(object,x,t)
{
	out<-NULL
	#checks
	if(missing(t)) t<-1 #default 1
	if(!is(object, "lifetable")) 
	  stop("Error! Need lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	if(any(x<0,t<0)) stop("Check x or t domain")

	deaths=dxt(object,x,t)
	lived=Lxt(object,x,t)
	out=deaths/lived
	return(out)
}

#death probability
qxt<-function(object, x, t, fractional="linear", decrement)
{
	out<-NULL
	#checks
	if(!(class(object) %in% c("lifetable","actuarialtable","mdt"))) 
	  stop("Error! Only lifetable, actuarialtable or mdt classes are accepted")
	if(missing(x)) stop("Missing x")
	if(any(x<0,t<0)) stop("Check x or t domain")
	if(missing(t)) t<-1 #default 1
	#complement of pxt
	out<-1-pxt(object=object, x=x, t=t, fractional=fractional, decrement=decrement)
	return(out)
}


#' Expected residual life.
#'
#' @param object A lifetable/actuarialtable object.
#' @param x Attained age
#' @param n Time until which the expected life should be calculated. Assumed omega - x whether missing.
#' @param type Either \code{"Tx"}, \code{"complete"} or \code{"continuous"} for continuous future lifetime, 
#' \code{"Kx"} or \code{"curtate"} for curtate furture lifetime (can be abbreviated).
#'
#' @return A numeric value representing the expected life span.
#' @author Giorgio Alfredo Spedicato
#' @references 	Actuarial Mathematics (Second Edition), 1997, by Bowers, N.L., Gerber, H.U., Hickman, J.C., 
#' Jones, D.A. and Nesbitt, C.J.
#' @seealso \code{\linkS4class{lifetable}}
#'
#' @examples
#' #loads and show
#' data(soa08Act)
#' exn(object=soa08Act, x=0)
#' exn(object=soa08Act, x=0,type="complete")
#' @export
exn<-function(object,x,n,type="curtate") {
	out<-NULL
	#checks
	if(!is(object, "lifetable")) stop("Error! Need lifetable or actuarialtable objects")
	if(missing(x)) x=0
	if(missing(n)) n=getOmega(object)-x +1 #to avoid errors
	if(n==0) return(0)
	probs=numeric(n)
	type <- testtypelifearg(type)
	
	if(type=="Kx"){
	for(i in 1:n) probs[i]=pxt(object,x,i)
	out=sum(probs)
	} else {
		lx=object@lx[which(object@x==x)]
		out=Lxt(object=object, x=x,t=n)/lx
	}
	return(out)
}

##################two life ###########


pxyt<-function(objectx, objecty,x,y,t, status="joint")
{
  .Deprecated("pxyzt")
  out<-NULL
	
	#checks
	if(!is(objectx, "lifetable")) stop("Error! Objectx needs be lifetable or actuarialtable objects")
	if(!is(objecty, "lifetable")) stop("Error! Objectx needs be lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	if(missing(y)) stop("Missing y")
	if(missing(t)) t=1 #default 1
	if(any(x<0,y<0,t<0)) stop("Check x, y and t domain")
	#joint survival status
  status <- teststatusarg(status)

	pxy=pxt(objectx, x,t)*pxt(objecty,y,t)
	if(status=="joint") out=pxy else out=pxt(objectx, x,t)+pxt(objecty,y,t)-pxy 
	return(out)
}

qxyt<-function(objectx, objecty,x,y,t, status="joint")
{
  .Deprecated("qxyzt")
  out<-NULL
	#checks
	if(!is(objectx, "lifetable")) stop("Error! Objectx needs be lifetable or actuarialtable objects")
	if(!is(objecty, "lifetable")) stop("Error! Objectx needs be lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	if(missing(y)) stop("Missing y")
	if(missing(t)) t=1 #default 1
	if(any(x<0,y<0,t<0)) stop("Check x, y and t domain")
	out=1-pxyt(objectx=objectx, objecty=objecty,x=x,y=y,t=t, status=status)
	return(out)
}

#to check

exyt<-function(objectx, objecty,x,y,t,status="joint")
{
  .Deprecated("exyzt")
  out<-NULL
	#checks
	if(!is(objectx, "lifetable")) stop("Error! Objectx needs be lifetable or actuarialtable objects")
	if(!is(objecty, "lifetable")) stop("Error! Objectx needs be lifetable or actuarialtable objects")
	if(missing(x)) stop("Missing x")
	if(missing(y)) stop("Missing y")
	maxTime=max(getOmega(objectx)-x, getOmega(objecty)-y)  #maximum number of years people can live togeter
	if(missing(t)) t=maxTime
	if(any(x<0,y<0,t<0)) stop("Check x, y and t domain")
	toSum=min(t,maxTime) #max number of years to sum
	times=1:toSum
	probs=numeric(length(times))
	#out=1-pxyt(objectx=objectx, objecty=objecty,x=x,y=y,t=t, status=status)
	for(i in 1:length(times)) probs[i]=pxyt(objectx=objectx, objecty=objecty,x=x,y=y,t=times[i], status=status)
	out=sum(probs)
	return(out)
}

probs2lifetable<-function(probs, radix=10000, type="px", name="ungiven")
{
	if(any(probs>1) | any(probs<0)) stop("Error: probabilities must lie between 0 an 1")
	if(!(type %in% c("px","qx"))) stop("Error: type must be either px or qx")
	if(type=="px" & probs[length(probs)]!=0) probs[length(probs)+1]=0;
	if(type=="qx" & probs[length(probs)]!=1) probs[length(probs)+1]=1;
  lx=numeric(length(probs))
	lx[1]=radix
	for(i in 2:length(probs))
	{
		if(type=="px") lx[i]=lx[i-1]*probs[i-1] else lx[i]=lx[i-1]*(1-probs[i-1])
	}
	out=new("lifetable",x=seq(0,length(probs)-1), lx=lx, name=name)
	return(out)
}

#multiple life new function
pxyztvect <- function(tablesList, x, t, status="joint", 
                      fractional=rep("linear",length(tablesList)), ...)
{
  #fractional list can be either missing or a string length of character one
  if(length(fractional)==1) 
  {
    temp <- fractional;
    fractional <- rep(temp, length.out =length(tablesList))
  }
  
  fractional <- sapply(fractional, testfractionnalarg)
  status <- teststatusarg(status)
  
  #initial checkings
  if (missing(x))
    stop("Missing x")
  if (!is.numeric(x))
    stop("non numeric x")
  if (missing(t))
    t = 1 #default 1
  #convert argument to matrix
  numTables <- length(tablesList)
  if(is.vector(x) && is.vector(t))
  {
    if(length(x) != numTables)
      stop("Error! Initial ages vector length does not match with number of lives")
    if(length(t) == 1)
      t <- rep(t, length.out=length(x))
    if(length(t) != numTables)
      stop("Error! Initial time vector length does not match with number of lives")
    valx <- t(as.matrix(x))
    valt <- t(as.matrix(t))
  }else if(is.matrix(x) && is.vector(t))
  {
    if(NCOL(x) != numTables)
      stop("Error! Initial ages matrix does not have as much column as number of lives")
    if(length(t) == 1)
      t <- rep(t, length.out=NCOL(x))
    if(length(t) != numTables)
      stop("Error! Initial time vector length does not match with number of lives")
    valx <- as.matrix(x)
    valt <- matrix(t, nrow=NROW(valx), ncol=numTables, byrow=TRUE)
  }else if(is.vector(x) && is.matrix(t))
  {
    if(length(x) != numTables)
      stop("Error! Initial ages vector length does not match with number of lives")
    if(NCOL(t) != numTables)
      stop("Error! Initial time matrix does not have as much column as number of lives")
    valt <- as.matrix(t)
    valx <- matrix(x, nrow=NROW(valt), ncol=numTables, byrow=TRUE)
  }else
  {
    if(NCOL(x) != numTables)
      stop("Error! Initial ages matrix does not have as much column as number of lives")
    if(NCOL(t) != numTables)
      stop("Error! Initial time matrix does not have as much column as number of lives")
    if(NROW(x) != NROW(t))
      warnings("t and x arguments have been recycled to match the maximum row number of x and t")
    n <- max(NROW(x), NROW(t))
    id2select <- rep(1:NROW(x), length.out=n)
    valx <- x[id2select, ]
    id2select <- rep(1:NROW(t), length.out=n)
    valt <- t[id2select, ]
  }
  #computation
  allpxt <- sapply(1:numTables, function(i)
                   pxtvect(tablesList[[i]], valx[,i], valt[,i], fractional = fractional[i], ...)
  )
  
  #the survival probability is the cumproduct of the single survival probabilities
  if(status == "joint")
  {
    if(is.vector(allpxt))
      out <- prod(allpxt)
    else 
      out <- apply(allpxt, 1, prod)
  }else{ #last survivor status
    allqxt <- 1-allpxt 
    if(is.vector(allpxt))
      out <- 1-prod(allqxt)
    else
      out <- 1-apply(allqxt, 1, prod)
  }
  return(out)
}

#multiple life new function
pxyzt<-function(tablesList,x,t, status="joint",fractional=rep("linear",length(tablesList)),...)
{
	out=1
	#fractional list can be either missing or a string length of character one
	if(length(fractional)==1) {temp<-fractional;fractional=rep(temp,length(tablesList))}
	
	fractional <- sapply(fractional, testfractionnalarg)
	status <- teststatusarg(status)
	
	#initial checkings
	
	numTables=length(tablesList)
	if(length(x)!=numTables) stop("Error! Initial ages vector length does not match with number of lives")
	for(i in 1:numTables) {
		if(!(class(tablesList[[i]]) %in% c("lifetable", "actuarialtable"))) stop("Error! A list of lifetable objects is required")
	}
	#the survival probability is the cumproduct of the single survival probabilities
	if(status=="joint")
	{
		for(i in 1:numTables) out=out*pxt(object=tablesList[[i]],x=x[i],t=t,fractional=fractional[i],...)
	} else { #last survivor status
		#calculate first qx the return the difference
		temp=1
		for(i in 1:numTables) temp=temp*qxt(object=tablesList[[i]],x=x[i],t=t,fractional=fractional[i],...)
		out=1-temp
	}
	return(out)
}
#the death probability
qxyzt<-function(tablesList,x,t, status="joint",fractional=rep("linear",length(tablesList)),...)
{
	out=numeric(1)
	out=1-pxyzt(tablesList=tablesList,x=x,t=t, status=status,...)
	return(out)
}

#probability to die between time n and n+t
.qxnt<-function(object, x,n,t=1,...)
{
	out=numeric(1)
	out=pxt(object=object,x=x,t=n,...)*qxt(object=object,x=x+n,t=t)
	return(out)
}


.qxyznt<-function(tablesList,x,n,t=1, status="joint")
{
	out=numeric(1)
	if(status=="joint")
	{
		y=x+n
		out=pxyzt(tablesList=tablesList,x=x,t=n, status=status)*qxyzt(tablesList=tablesList,x=y,t=t, status=status)
	} else { #last
		y=n+t
		out=pxyzt(tablesList=tablesList,x=x,t=n, status=status)-pxyzt(tablesList=tablesList,x=x,t=y, status=status)
	}
	return(out)
}

#curtate expectation of future lifetime

exyzt<-function(tablesList,x,t=Inf, status="joint",type="Kx",...)
{
	#initial checkings
	numTables=length(tablesList)
	if(length(x)!=numTables) stop("Error! Initial ages vector length does not match with number of lives")
	for(i in 1:numTables) {
	if(!(class(tablesList[[i]]) %in% c("lifetable", "actuarialtable"))) stop("Error! A list of lifetable objects is required")
	}
	type <- testtypelifearg(type)
	status <- teststatusarg(status)
	
	#get the max omega
	maxAge=0 
	for(i in 1:numTables)
	{
		maxAge=max(maxAge, getOmega(tablesList[[i]]))
	}
	minAge=min(x)
	term=0
	#curtate expectation of future lifetime
	if(missing(t)||is.infinite(t)) term=maxAge-minAge+1 else term=t
	#perform the calculation
	out=0
	for(j in 1:term) out=out+pxyzt(tablesList=tablesList,x=x,t=j, status=status,...)
	if(type=="Tx") out=out+0.5
	return(out)
}

#' @name mx2qx
#' @title Mortality rates to Death probabilities
#' 
#' @description Function to convert mortality rates to probabilities of death
#'
#' @details Function to convert mortality rates to probabilities of death
#' 
#' @param mx mortality rates vector
#' @param ax the average number of years lived between ages x and x +1 by individuals who die in that interval
#' 
#' @return A vector of death probabilities
#' @examples 
#' 
#' #using some recursion
#' qx2mx(mx2qx(.2))
#' 
#' @seealso \code{mxt}, \code{qxt}, \code{qx2mx}

mx2qx <- function(mx, ax = 0.5)
{
  out <- mx / (1 +  (1 - ax)*mx)
  return(out)
}

#' @name qx2mx
#' @title Death Probabilities to Mortality Rates
#' 
#' @description Function to convert death probabilities to mortality rates
#'
#' @details Function to convert death probabilities to mortality rates
#' 
#' @param qx death probabilities
#' @param ax the average number of years lived between ages x and x +1 by individuals who die in that interval
#' 
#' @return A vector of mortality rates
#' @examples 
#' data(soa08Act)
#' soa08qx<-as(soa08Act,"numeric")
#' soa08mx<-qx2mx(qx=soa08qx)
#' soa08qx2<-mx2qx(soa08mx)
#' @seealso \code{mxt}, \code{qxt}, \code{mx2qx}

qx2mx <- function(qx, ax=0.5) {
  out <- qx/(1+ax*qx-qx)
  return(out)
}
