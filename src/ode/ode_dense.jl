ode_interpolant(Θ,Δt,y₀,y₁,k₀,k₁,alg::Symbol) = ode_interpolant(Θ,Δt,y₀,y₁,k₀,k₁,Val{alg}) # Dispatch interpolant by alg
ode_interpolation(tvals,ts,timeseries,ks,alg::Symbol,f) = ode_interpolation(tvals,ts,timeseries,ks,Val{alg},f) # Dispatch by alg
ode_addsteps!(k,t,u,Δt,alg::Symbol,f) = ode_addsteps!(k,t,u,Δt,f,Val{alg},typeof(k[1]./Δt),eltype(k[1]./k[1]))

"""
ode_interpolation(tvals,ts,timeseries,ks)

Get the value at tvals where the solution is known at the
times ts (sorted), with values timeseries and derivatives ks
"""
function ode_interpolation{alg}(tvals,ts,timeseries,ks,T::Type{Val{alg}},f)
  if typeof(tvals) <: StepRange
  else
    sort!(tvals) # Make sure it's sorted
  end
  i = 2 # Start the search thinking it's between ts[1] and ts[2]
  vals = Vector{eltype(timeseries)}(0)
  for t in tvals
    i = findfirst((x)->x>=t,ts[i:end])+i-1 # It's in the interval ts[i-1] to ts[i]
    if ts[i] == t
      push!(vals,timeseries[i])
    elseif ts[i-1] == t # Can happen if it's the first value!
      push!(vals,timeseries[i-1])
    else
      Δt = ts[i] - ts[i-1]
      Θ = (t-ts[i-1])/Δt
      ode_addsteps!(ks[i],ts[i-1],timeseries[i-1],Δt,alg,f) # update the kcurrent, since kprevious not used in special algs
      push!(vals,ode_interpolant(Θ,Δt,timeseries[i-1],timeseries[i],ks[i-1],ks[i],alg))
    end
  end
  vals
end

"""
ode_interpolation(tval::Number,ts,timeseries,ks)

Get the value at tvals where the solution is known at the
times ts (sorted), with values timeseries and derivatives ks
"""
function ode_interpolation{alg}(tval::Number,ts,timeseries,ks,T::Type{Val{alg}},f)
  i = findfirst((x)->x>=tval,ts) # It's in the interval ts[i-1] to ts[i]
  if ts[i] == tval
    val = timeseries[i]
  elseif ts[i-1] == tval # Can happen if it's the first value!
    push!(vals,timeseries[i-1])
  else
    Δt = ts[i] - ts[i-1]
    Θ = (tval-ts[i-1])/Δt
    ode_addsteps!(ks[i],ts[i-1],timeseries[i-1],Δt,alg,f) # update the kcurrent, since kprevious not used in special algs
    val = ode_interpolant(Θ,Δt,timeseries[i-1],timeseries[i],ks[i-1],ks[i],alg)
  end
  val
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 190

Herimte Interpolation, chosen if no other dispatch for ode_interpolant
"""
function ode_interpolant{alg}(Θ,Δt,y₀,y₁,k₀,k₁,T::Type{Val{alg}}) # Default interpolant is Hermite
  (1-Θ)*y₀+Θ*y₁+Θ*(Θ-1)*((1-2Θ)*(y₁-y₀)+(Θ-1)*Δt*k₀ + Θ*Δt*k₁)
end

"""
By default, never add steps (no op)
"""
function ode_addsteps!{rateType,uEltypeNoUnits,alg}(k,t,u,Δt,f,T::Type{Val{alg}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 190
"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:DP5}})
  b1,b3,b4,b5,b6,b7 = DP5_dense_bs(eltype(y₀/y₀)) # Divide away the units
  b7Θ = Θ^2 * (Θ-1) + Θ^2 * (Θ-1)^2 *10*(7414447 - 829305Θ)/29380423
  b1Θ = Θ^2 * (3-2Θ)*b1 + Θ*(Θ-1)^2 - Θ^2*(Θ-1)^2 *5*(2558722523 - 31403016Θ)/11282082432
  b3Θ = Θ^2 * (3-2Θ)*b3 + Θ^2 * (Θ-1)^2 * 100   * (882725551 - 15701508Θ)/32700410799
  b4Θ = Θ^2 * (3-2Θ)*b4 - Θ^2 * (Θ-1)^2 * 25    * (443332067 - 31403016Θ)/1880347072
  b5Θ = Θ^2 * (3-2Θ)*b5 + Θ^2 * (Θ-1)^2 * 32805 * (23143187  - 3489224Θ )/199316789632
  b6Θ = Θ^2 * (3-2Θ)*b6 - Θ^2 * (Θ-1)^2 * 55    * (29972135  - 7076736Θ )/822651844
  y₀ + Δt*(k[1]*b1Θ + k[2]*b3Θ + k[3]*b4Θ + k[4]*b5Θ + k[5]*b6Θ + k[6]*b7Θ) # No k2
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 190
"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:DP5Vectorized}})
  b1,b3,b4,b5,b6,b7 = DP5_dense_bs(eltype(y₀/y₀)) # Divide away the units
  b7Θ = Θ^2 * (Θ-1) + Θ^2 * (Θ-1)^2 *10*(7414447 - 829305Θ)/29380423
  b1Θ = Θ^2 * (3-2Θ)*b1 + Θ*(Θ-1)^2 - Θ^2*(Θ-1)^2 *5*(2558722523 - 31403016Θ)/11282082432
  b3Θ = Θ^2 * (3-2Θ)*b3 + Θ^2 * (Θ-1)^2 * 100   * (882725551 - 15701508Θ)/32700410799
  b4Θ = Θ^2 * (3-2Θ)*b4 - Θ^2 * (Θ-1)^2 * 25    * (443332067 - 31403016Θ)/1880347072
  b5Θ = Θ^2 * (3-2Θ)*b5 + Θ^2 * (Θ-1)^2 * 32805 * (23143187  - 3489224Θ )/199316789632
  b6Θ = Θ^2 * (3-2Θ)*b6 - Θ^2 * (Θ-1)^2 * 55    * (29972135  - 7076736Θ )/822651844
  y₀ + Δt*(k[1]*b1Θ + k[2]*b3Θ + k[3]*b4Θ + k[4]*b5Θ + k[5]*b6Θ + k[6]*b7Θ) # No k2
end

function DP5_dense_bs(T)
  b1  = T(5179//57600)
  b3  = T(7571//16695)
  b4  = T(393//640)
  b5  = T(-92097//339200)
  b6  = T(187//2100)
  b7  = T(1//40)
  return b1,b3,b4,b5,b6,b7
end

"""
Runge–Kutta pairs of order 5(4) satisfying only the first column
simplifying assumption

Ch. Tsitouras
"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:Tsit5}})
  b1Θ = -1.0530884977290216Θ * (Θ - 1.3299890189751412)*(Θ^2 - 1.4364028541716351Θ + 0.7139816917074209)
  b2Θ = 0.1017Θ^2 * (Θ^2 - 2.1966568338249754Θ + 1.2949852507374631)
  b3Θ = 2.490627285651252793Θ^2 * (Θ^2 - 2.38535645472061657Θ + 1.57803468208092486)
  b4Θ = -16.54810288924490272*(Θ - 1.21712927295533244)*(Θ - 0.61620406037800089)*Θ^2
  b5Θ = 47.37952196281928122*(Θ - 1.203071208372362603)*(Θ - 0.658047292653547382)*Θ^2
  b6Θ = -34.87065786149660974*(Θ - 1.2)*(Θ - 0.666666666666666667)*Θ^2
  b7Θ = 2.5*(Θ - 1)*(Θ - 0.6)*Θ^2
  y₀ + Δt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
end

"""
Runge–Kutta pairs of order 5(4) satisfying only the first column
simplifying assumption

Ch. Tsitouras
"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:Tsit5Vectorized}})
  b1Θ = -1.0530884977290216Θ * (Θ - 1.3299890189751412)*(Θ^2 - 1.4364028541716351Θ + 0.7139816917074209)
  b2Θ = 0.1017Θ^2 * (Θ^2 - 2.1966568338249754Θ + 1.2949852507374631)
  b3Θ = 2.490627285651252793Θ^2 * (Θ^2 - 2.38535645472061657Θ + 1.57803468208092486)
  b4Θ = -16.54810288924490272*(Θ - 1.21712927295533244)*(Θ - 0.61620406037800089)*Θ^2
  b5Θ = 47.37952196281928122*(Θ - 1.203071208372362603)*(Θ - 0.658047292653547382)*Θ^2
  b6Θ = -34.87065786149660974*(Θ - 1.2)*(Θ - 0.666666666666666667)*Θ^2
  b7Θ = 2.5*(Θ - 1)*(Θ - 0.6)*Θ^2
  y₀ + Δt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
end

"""
Coefficients taken from RKSuite
"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:BS5}})
  r016,r015,r014,r013,r012,r011,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r092,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = BS5Interp_polyweights(eltype(y₀))
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  b1Θ =           r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b3Θ =           r032*Θ2 + r033*Θ3 + r034*Θ4 + r035*Θ5 + r036*Θ6
  b4Θ =           r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =           r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =           r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =           r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =           r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =           r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=           r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=           r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  y₀ + Δt*Θ*k[1] - Δt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
end

"""
Coefficients taken from RKSuite
"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:BS5Vectorized}})
  r016,r015,r014,r013,r012,r011,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r092,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = BS5Interp_polyweights(eltype(y₀))
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  b1Θ =           r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b3Θ =           r032*Θ2 + r033*Θ3 + r034*Θ4 + r035*Θ5 + r036*Θ6
  b4Θ =           r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =           r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =           r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =           r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =           r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =           r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=           r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=           r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  y₀ + Δt*(k[1]*b1Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
end

"""

"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:Vern6}})
  r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = Vern6Interp_polyweights(eltype(y₀))
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6
  b4Θ =          r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6
  b5Θ =          r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6
  y₀ + Δt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
end

"""

"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:Vern7}})
  r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = Vern7Interp_polyweights(eltype(y₀))
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7
  b4Θ =          r042*Θ2 + r043*Θ3 + r044*Θ4 + r045*Θ5 + r046*Θ6 + r047*Θ7
  b5Θ =          r052*Θ2 + r053*Θ3 + r054*Θ4 + r055*Θ5 + r056*Θ6 + r057*Θ7
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6 + r067*Θ7
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6 + r077*Θ7
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7
  b13Θ=          r132*Θ2 + r133*Θ3 + r134*Θ4 + r135*Θ5 + r136*Θ6 + r137*Θ7
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7
  b16Θ=          r162*Θ2 + r163*Θ3 + r164*Θ4 + r165*Θ5 + r166*Θ6 + r167*Θ7
  y₀ + Δt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
end

"""

"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:Vern8}})
  r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = Vern8Interp_polyweights(eltype(y₀))
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  Θ8 = Θ7*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7 + r018*Θ8
  b6Θ =          r062*Θ2 + r063*Θ3 + r064*Θ4 + r065*Θ5 + r066*Θ6 + r067*Θ7 + r068*Θ8
  b7Θ =          r072*Θ2 + r073*Θ3 + r074*Θ4 + r075*Θ5 + r076*Θ6 + r077*Θ7 + r078*Θ8
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7 + r088*Θ8
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7 + r098*Θ8
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6 + r107*Θ7 + r108*Θ8
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7 + r118*Θ8
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7 + r128*Θ8
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7 + r148*Θ8
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7 + r158*Θ8
  b16Θ=          r162*Θ2 + r163*Θ3 + r164*Θ4 + r165*Θ5 + r166*Θ6 + r167*Θ7 + r168*Θ8
  b17Θ=          r172*Θ2 + r173*Θ3 + r174*Θ4 + r175*Θ5 + r176*Θ6 + r177*Θ7 + r178*Θ8
  b18Θ=          r182*Θ2 + r183*Θ3 + r184*Θ4 + r185*Θ5 + r186*Θ6 + r187*Θ7 + r188*Θ8
  b19Θ=          r192*Θ2 + r193*Θ3 + r194*Θ4 + r195*Θ5 + r196*Θ6 + r197*Θ7 + r198*Θ8
  b20Θ=          r202*Θ2 + r203*Θ3 + r204*Θ4 + r205*Θ5 + r206*Θ6 + r207*Θ7 + r208*Θ8
  b21Θ=          r212*Θ2 + r213*Θ3 + r214*Θ4 + r215*Θ5 + r216*Θ6 + r217*Θ7 + r218*Θ8
  y₀ + Δt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ)
end

"""

"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:Vern9}})
  r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = Vern9Interp_polyweights(eltype(y₀))
  Θ2 = Θ^2
  Θ3 = Θ2*Θ
  Θ4 = Θ3*Θ
  Θ5 = Θ4*Θ
  Θ6 = Θ5*Θ
  Θ7 = Θ6*Θ
  Θ8 = Θ7*Θ
  Θ9 = Θ8*Θ
  b1Θ = r011*Θ + r012*Θ2 + r013*Θ3 + r014*Θ4 + r015*Θ5 + r016*Θ6 + r017*Θ7 + r018*Θ8 + r019*Θ9
  b8Θ =          r082*Θ2 + r083*Θ3 + r084*Θ4 + r085*Θ5 + r086*Θ6 + r087*Θ7 + r088*Θ8 + r089*Θ9
  b9Θ =          r092*Θ2 + r093*Θ3 + r094*Θ4 + r095*Θ5 + r096*Θ6 + r097*Θ7 + r098*Θ8 + r099*Θ9
  b10Θ=          r102*Θ2 + r103*Θ3 + r104*Θ4 + r105*Θ5 + r106*Θ6 + r107*Θ7 + r108*Θ8 + r109*Θ9
  b11Θ=          r112*Θ2 + r113*Θ3 + r114*Θ4 + r115*Θ5 + r116*Θ6 + r117*Θ7 + r118*Θ8 + r119*Θ9
  b12Θ=          r122*Θ2 + r123*Θ3 + r124*Θ4 + r125*Θ5 + r126*Θ6 + r127*Θ7 + r128*Θ8 + r129*Θ9
  b13Θ=          r132*Θ2 + r133*Θ3 + r134*Θ4 + r135*Θ5 + r136*Θ6 + r137*Θ7 + r138*Θ8 + r139*Θ9
  b14Θ=          r142*Θ2 + r143*Θ3 + r144*Θ4 + r145*Θ5 + r146*Θ6 + r147*Θ7 + r148*Θ8 + r149*Θ9
  b15Θ=          r152*Θ2 + r153*Θ3 + r154*Θ4 + r155*Θ5 + r156*Θ6 + r157*Θ7 + r158*Θ8 + r159*Θ9
  b17Θ=          r172*Θ2 + r173*Θ3 + r174*Θ4 + r175*Θ5 + r176*Θ6 + r177*Θ7 + r178*Θ8 + r179*Θ9
  b18Θ=          r182*Θ2 + r183*Θ3 + r184*Θ4 + r185*Θ5 + r186*Θ6 + r187*Θ7 + r188*Θ8 + r189*Θ9
  b19Θ=          r192*Θ2 + r193*Θ3 + r194*Θ4 + r195*Θ5 + r196*Θ6 + r197*Θ7 + r198*Θ8 + r199*Θ9
  b20Θ=          r202*Θ2 + r203*Θ3 + r204*Θ4 + r205*Θ5 + r206*Θ6 + r207*Θ7 + r208*Θ8 + r209*Θ9
  b21Θ=          r212*Θ2 + r213*Θ3 + r214*Θ4 + r215*Θ5 + r216*Θ6 + r217*Θ7 + r218*Θ8 + r219*Θ9
  b22Θ=          r222*Θ2 + r223*Θ3 + r224*Θ4 + r225*Θ5 + r226*Θ6 + r227*Θ7 + r228*Θ8 + r229*Θ9
  b23Θ=          r232*Θ2 + r233*Θ3 + r234*Θ4 + r235*Θ5 + r236*Θ6 + r237*Θ7 + r238*Θ8 + r239*Θ9
  b24Θ=          r242*Θ2 + r243*Θ3 + r244*Θ4 + r245*Θ5 + r246*Θ6 + r247*Θ7 + r248*Θ8 + r249*Θ9
  b25Θ=          r252*Θ2 + r253*Θ3 + r254*Θ4 + r255*Θ5 + r256*Θ6 + r257*Θ7 + r258*Θ8 + r259*Θ9
  b26Θ=          r262*Θ2 + r263*Θ3 + r264*Θ4 + r265*Θ5 + r266*Θ6 + r267*Θ7 + r268*Θ8 + r269*Θ9
  y₀ + Δt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ + k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
end

"""

"""
function ode_interpolant(Θ,Δt,y₀,y₁,kprevious,k,T::Type{Val{:DP8}})
  r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = Vern9Interp_polyweights(eltype(y₀))
  Θ1 = 1-Θ
  conpar = k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))
  y₀ + Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*Δt*conpar)))
end


"""
An Efficient Runge-Kutta (4,5) Pair by P.Bogacki and L.F.Shampine
 Computers and Mathematics with Applications, Vol. 32, No. 6, 1996, pages 15 to 28

Called to add the extra k9, k10, k11 steps for the Order 5 interpolation when needed
"""
function ode_addsteps!{rateType<:Number,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:BS5}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 11 # Have not added the extra stages yet
    c6,c7,c8,a91,a92,a93,a94,a95,a96,a97,a98,a101,a102,a103,a104,a105,a106,a107,a108,a109,a111,a112,a113,a114,a115,a116,a117,a118,a119,a1110 = BS5Interp(uEltypeNoUnits)
    push!(k,f(t+c6*Δt,u+Δt*(a91*k[1]+a92*k[2]+a93*k[3]+a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8])))
    push!(k,f(t+c7*Δt,u+Δt*(a101*k[1]+a102*k[2]+a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7]+a108*k[8]+a109*k[9])))
    push!(k,f(t+c8*Δt,u+Δt*(a111*k[1]+a112*k[2]+a113*k[3]+a114*k[4]+a115*k[5]+a116*k[6]+a117*k[7]+a118*k[8]+a119*k[9]+a1110*k[10])))
  end
  nothing
end

"""
An Efficient Runge-Kutta (4,5) Pair by P.Bogacki and L.F.Shampine
 Computers and Mathematics with Applications, Vol. 32, No. 6, 1996, pages 15 to 28

Called to add the extra k9, k10, k11 steps for the Order 5 interpolation when needed
"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:BS5}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 11 # Have not added the extra stages yet
    c6,c7,c8,a91,a92,a93,a94,a95,a96,a97,a98,a101,a102,a103,a104,a105,a106,a107,a108,a109,a111,a112,a113,a114,a115,a116,a117,a118,a119,a1110 = BS5Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c6*Δt,u+Δt*(a91*k[1]+a92*k[2]+a93*k[3]+a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8]),rtmp); push!(k,copy(rtmp))
    f(t+c7*Δt,u+Δt*(a101*k[1]+a102*k[2]+a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7]+a108*k[8]+a109*k[9]),rtmp); push!(k,copy(rtmp))
    f(t+c8*Δt,u+Δt*(a111*k[1]+a112*k[2]+a113*k[3]+a114*k[4]+a115*k[5]+a116*k[6]+a117*k[7]+a118*k[8]+a119*k[9]+a1110*k[10]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""
An Efficient Runge-Kutta (4,5) Pair by P.Bogacki and L.F.Shampine
 Computers and Mathematics with Applications, Vol. 32, No. 6, 1996, pages 15 to 28

Called to add the extra k9, k10, k11 steps for the Order 5 interpolation when needed
"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:BS5Vectorized}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 11 # Have not added the extra stages yet
    c6,c7,c8,a91,a92,a93,a94,a95,a96,a97,a98,a101,a102,a103,a104,a105,a106,a107,a108,a109,a111,a112,a113,a114,a115,a116,a117,a118,a119,a1110 = BS5Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c6*Δt,u+Δt*(a91*k[1]+a92*k[2]+a93*k[3]+a94*k[4]+a95*k[5]+a96*k[6]+a97*k[7]+a98*k[8]),rtmp); push!(k,copy(rtmp))
    f(t+c7*Δt,u+Δt*(a101*k[1]+a102*k[2]+a103*k[3]+a104*k[4]+a105*k[5]+a106*k[6]+a107*k[7]+a108*k[8]+a109*k[9]),rtmp); push!(k,copy(rtmp))
    f(t+c8*Δt,u+Δt*(a111*k[1]+a112*k[2]+a113*k[3]+a114*k[4]+a115*k[5]+a116*k[6]+a117*k[7]+a118*k[8]+a119*k[9]+a1110*k[10]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:Number,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern6}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 12 # Have not added the extra stages yet
    c10,a1001,a1004,a1005,a1006,a1007,a1008,a1009,c11,a1101,a1102,a1103,a1104,a1105,a1106,a1107,a1108,a1109,a1110,c12,a1201,a1202,a1203,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = Vern6Interp(uEltypeNoUnits)
    push!(k,f(t+c10*Δt,u+Δt*(a1001*k[1]+a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9])))
    push!(k,f(t+c11*Δt,u+Δt*(a1101*k[1]+a1102*k[2]+a1103*k[3]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10])))
    push!(k,f(t+c12*Δt,u+Δt*(a1201*k[1]+a1202*k[2]+a1203*k[3]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11])))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern6}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 12 # Have not added the extra stages yet
    c10,a1001,a1004,a1005,a1006,a1007,a1008,a1009,c11,a1101,a1102,a1103,a1104,a1105,a1106,a1107,a1108,a1109,a1110,c12,a1201,a1202,a1203,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = Vern6Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c10*Δt,u+Δt*(a1001*k[1]+a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9]),rtmp); push!(k,copy(rtmp))
    f(t+c11*Δt,u+Δt*(a1101*k[1]+a1102*k[2]+a1103*k[3]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10]),rtmp); push!(k,copy(rtmp))
    f(t+c12*Δt,u+Δt*(a1201*k[1]+a1202*k[2]+a1203*k[3]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern6Vectorized}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 12 # Have not added the extra stages yet
    c10,a1001,a1004,a1005,a1006,a1007,a1008,a1009,c11,a1101,a1102,a1103,a1104,a1105,a1106,a1107,a1108,a1109,a1110,c12,a1201,a1202,a1203,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211 = Vern6Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c10*Δt,u+Δt*(a1001*k[1]+a1004*k[4]+a1005*k[5]+a1006*k[6]+a1007*k[7]+a1008*k[8]+a1009*k[9]),rtmp); push!(k,copy(rtmp))
    f(t+c11*Δt,u+Δt*(a1101*k[1]+a1102*k[2]+a1103*k[3]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]+a1110*k[10]),rtmp); push!(k,copy(rtmp))
    f(t+c12*Δt,u+Δt*(a1201*k[1]+a1202*k[2]+a1203*k[3]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1210*k[10]+a1211*k[11]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:Number,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern7}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 16 # Have not added the extra stages yet
    c11,a1101,a1104,a1105,a1106,a1107,a1108,a1109,c12,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1211,c13,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1311,a1312,c14,a1401,a1404,a1405,a1406,a1407,a1408,a1409,a1411,a1412,a1413,c15,a1501,a1504,a1505,a1506,a1507,a1508,a1509,a1511,a1512,a1513,c16,a1601,a1604,a1605,a1606,a1607,a1608,a1609,a1611,a1612,a1613 = Vern7Interp(uEltypeNoUnits)
    push!(k,f(t+c11*Δt,u+Δt*(a1101*k[1]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9])))
    push!(k,f(t+c12*Δt,u+Δt*(a1201*k[1]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1211*k[11])))
    push!(k,f(t+c13*Δt,u+Δt*(a1301*k[1]+a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1311*k[11]+a1312*k[12])))
    push!(k,f(t+c14*Δt,u+Δt*(a1401*k[1]+a1404*k[4]+a1405*k[5]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1411*k[11]+a1412*k[12]+a1413*k[13])))
    push!(k,f(t+c15*Δt,u+Δt*(a1501*k[1]+a1504*k[4]+a1505*k[5]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1511*k[11]+a1512*k[12]+a1513*k[13])))
    push!(k,f(t+c16*Δt,u+Δt*(a1601*k[1]+a1604*k[4]+a1605*k[5]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1611*k[11]+a1612*k[12]+a1613*k[13])))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern7}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 16 # Have not added the extra stages yet
    c11,a1101,a1104,a1105,a1106,a1107,a1108,a1109,c12,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1211,c13,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1311,a1312,c14,a1401,a1404,a1405,a1406,a1407,a1408,a1409,a1411,a1412,a1413,c15,a1501,a1504,a1505,a1506,a1507,a1508,a1509,a1511,a1512,a1513,c16,a1601,a1604,a1605,a1606,a1607,a1608,a1609,a1611,a1612,a1613 = Vern7Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c11*Δt,u+Δt*(a1101*k[1]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]),rtmp); push!(k,copy(rtmp))
    f(t+c12*Δt,u+Δt*(a1201*k[1]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1211*k[11]),rtmp); push!(k,copy(rtmp))
    f(t+c13*Δt,u+Δt*(a1301*k[1]+a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1311*k[11]+a1312*k[12]),rtmp); push!(k,copy(rtmp))
    f(t+c14*Δt,u+Δt*(a1401*k[1]+a1404*k[4]+a1405*k[5]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1411*k[11]+a1412*k[12]+a1413*k[13]),rtmp); push!(k,copy(rtmp))
    f(t+c15*Δt,u+Δt*(a1501*k[1]+a1504*k[4]+a1505*k[5]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1511*k[11]+a1512*k[12]+a1513*k[13]),rtmp); push!(k,copy(rtmp))
    f(t+c16*Δt,u+Δt*(a1601*k[1]+a1604*k[4]+a1605*k[5]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1611*k[11]+a1612*k[12]+a1613*k[13]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern7Vectorized}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 16 # Have not added the extra stages yet
    c11,a1101,a1104,a1105,a1106,a1107,a1108,a1109,c12,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1211,c13,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1311,a1312,c14,a1401,a1404,a1405,a1406,a1407,a1408,a1409,a1411,a1412,a1413,c15,a1501,a1504,a1505,a1506,a1507,a1508,a1509,a1511,a1512,a1513,c16,a1601,a1604,a1605,a1606,a1607,a1608,a1609,a1611,a1612,a1613 = Vern7Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c11*Δt,u+Δt*(a1101*k[1]+a1104*k[4]+a1105*k[5]+a1106*k[6]+a1107*k[7]+a1108*k[8]+a1109*k[9]),rtmp); push!(k,copy(rtmp))
    f(t+c12*Δt,u+Δt*(a1201*k[1]+a1204*k[4]+a1205*k[5]+a1206*k[6]+a1207*k[7]+a1208*k[8]+a1209*k[9]+a1211*k[11]),rtmp); push!(k,copy(rtmp))
    f(t+c13*Δt,u+Δt*(a1301*k[1]+a1304*k[4]+a1305*k[5]+a1306*k[6]+a1307*k[7]+a1308*k[8]+a1309*k[9]+a1311*k[11]+a1312*k[12]),rtmp); push!(k,copy(rtmp))
    f(t+c14*Δt,u+Δt*(a1401*k[1]+a1404*k[4]+a1405*k[5]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1411*k[11]+a1412*k[12]+a1413*k[13]),rtmp); push!(k,copy(rtmp))
    f(t+c15*Δt,u+Δt*(a1501*k[1]+a1504*k[4]+a1505*k[5]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1511*k[11]+a1512*k[12]+a1513*k[13]),rtmp); push!(k,copy(rtmp))
    f(t+c16*Δt,u+Δt*(a1601*k[1]+a1604*k[4]+a1605*k[5]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1611*k[11]+a1612*k[12]+a1613*k[13]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:Number,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern8}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 21 # Have not added the extra stages yet
    c14,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,c15,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1514,c16,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1614,a1615,c17,a1701,a1706,a1707,a1708,a1709,a1710,a1711,a1712,a1714,a1715,a1716,c18,a1801,a1806,a1807,a1808,a1809,a1810,a1811,a1812,a1814,a1815,a1816,a1817,c19,a1901,a1906,a1907,a1908,a1909,a1910,a1911,a1912,a1914,a1915,a1916,a1917,c20,a2001,a2006,a2007,a2008,a2009,a2010,a2011,a2012,a2014,a2015,a2016,a2017,c21,a2101,a2106,a2107,a2108,a2109,a2110,a2111,a2112,a2114,a2115,a2116,a2117 = Vern8Interp(uEltypeNoUnits)
    push!(k,f(t+c14*Δt,u+Δt*(a1401*k[1]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12])))
    push!(k,f(t+c15*Δt,u+Δt*(a1501*k[1]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1514*k[14])))
    push!(k,f(t+c16*Δt,u+Δt*(a1601*k[1]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1614*k[14]+a1615*k[15])))
    push!(k,f(t+c17*Δt,u+Δt*(a1701*k[1]+a1706*k[6]+a1707*k[7]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1714*k[14]+a1715*k[15]+a1716*k[16])))
    push!(k,f(t+c18*Δt,u+Δt*(a1801*k[1]+a1806*k[6]+a1807*k[7]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1814*k[14]+a1815*k[15]+a1816*k[16]+a1817*k[17])))
    push!(k,f(t+c19*Δt,u+Δt*(a1901*k[1]+a1906*k[6]+a1907*k[7]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1914*k[14]+a1915*k[15]+a1916*k[16]+a1917*k[17])))
    push!(k,f(t+c20*Δt,u+Δt*(a2001*k[1]+a2006*k[6]+a2007*k[7]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2014*k[14]+a2015*k[15]+a2016*k[16]+a2017*k[17])))
    push!(k,f(t+c21*Δt,u+Δt*(a2101*k[1]+a2106*k[6]+a2107*k[7]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2114*k[14]+a2115*k[15]+a2116*k[16]+a2117*k[17])))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern8}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 21 # Have not added the extra stages yet
    c14,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,c15,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1514,c16,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1614,a1615,c17,a1701,a1706,a1707,a1708,a1709,a1710,a1711,a1712,a1714,a1715,a1716,c18,a1801,a1806,a1807,a1808,a1809,a1810,a1811,a1812,a1814,a1815,a1816,a1817,c19,a1901,a1906,a1907,a1908,a1909,a1910,a1911,a1912,a1914,a1915,a1916,a1917,c20,a2001,a2006,a2007,a2008,a2009,a2010,a2011,a2012,a2014,a2015,a2016,a2017,c21,a2101,a2106,a2107,a2108,a2109,a2110,a2111,a2112,a2114,a2115,a2116,a2117 = Vern8Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c14*Δt,u+Δt*(a1401*k[1]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12]),rtmp); push!(k,copy(rtmp))
    f(t+c15*Δt,u+Δt*(a1501*k[1]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1514*k[14]),rtmp); push!(k,copy(rtmp))
    f(t+c16*Δt,u+Δt*(a1601*k[1]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1614*k[14]+a1615*k[15]),rtmp); push!(k,copy(rtmp))
    f(t+c17*Δt,u+Δt*(a1701*k[1]+a1706*k[6]+a1707*k[7]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1714*k[14]+a1715*k[15]+a1716*k[16]),rtmp); push!(k,copy(rtmp))
    f(t+c18*Δt,u+Δt*(a1801*k[1]+a1806*k[6]+a1807*k[7]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1814*k[14]+a1815*k[15]+a1816*k[16]+a1817*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c19*Δt,u+Δt*(a1901*k[1]+a1906*k[6]+a1907*k[7]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1914*k[14]+a1915*k[15]+a1916*k[16]+a1917*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c20*Δt,u+Δt*(a2001*k[1]+a2006*k[6]+a2007*k[7]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2014*k[14]+a2015*k[15]+a2016*k[16]+a2017*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c21*Δt,u+Δt*(a2101*k[1]+a2106*k[6]+a2107*k[7]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2114*k[14]+a2115*k[15]+a2116*k[16]+a2117*k[17]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern8Vectorized}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 26 # Have not added the extra stages yet
    c14,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,c15,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1514,c16,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1614,a1615,c17,a1701,a1706,a1707,a1708,a1709,a1710,a1711,a1712,a1714,a1715,a1716,c18,a1801,a1806,a1807,a1808,a1809,a1810,a1811,a1812,a1814,a1815,a1816,a1817,c19,a1901,a1906,a1907,a1908,a1909,a1910,a1911,a1912,a1914,a1915,a1916,a1917,c20,a2001,a2006,a2007,a2008,a2009,a2010,a2011,a2012,a2014,a2015,a2016,a2017,c21,a2101,a2106,a2107,a2108,a2109,a2110,a2111,a2112,a2114,a2115,a2116,a2117 = Vern8Interp(uEltypeNoUnits)
    rtmp = rateType(size(k[1]))
    f(t+c14*Δt,u+Δt*(a1401*k[1]+a1406*k[6]+a1407*k[7]+a1408*k[8]+a1409*k[9]+a1410*k[10]+a1411*k[11]+a1412*k[12]),rtmp); push!(k,copy(rtmp))
    f(t+c15*Δt,u+Δt*(a1501*k[1]+a1506*k[6]+a1507*k[7]+a1508*k[8]+a1509*k[9]+a1510*k[10]+a1511*k[11]+a1512*k[12]+a1514*k[14]),rtmp); push!(k,copy(rtmp))
    f(t+c16*Δt,u+Δt*(a1601*k[1]+a1606*k[6]+a1607*k[7]+a1608*k[8]+a1609*k[9]+a1610*k[10]+a1611*k[11]+a1612*k[12]+a1614*k[14]+a1615*k[15]),rtmp); push!(k,copy(rtmp))
    f(t+c17*Δt,u+Δt*(a1701*k[1]+a1706*k[6]+a1707*k[7]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1714*k[14]+a1715*k[15]+a1716*k[16]),rtmp); push!(k,copy(rtmp))
    f(t+c18*Δt,u+Δt*(a1801*k[1]+a1806*k[6]+a1807*k[7]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1814*k[14]+a1815*k[15]+a1816*k[16]+a1817*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c19*Δt,u+Δt*(a1901*k[1]+a1906*k[6]+a1907*k[7]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1914*k[14]+a1915*k[15]+a1916*k[16]+a1917*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c20*Δt,u+Δt*(a2001*k[1]+a2006*k[6]+a2007*k[7]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2014*k[14]+a2015*k[15]+a2016*k[16]+a2017*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c21*Δt,u+Δt*(a2101*k[1]+a2106*k[6]+a2107*k[7]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2114*k[14]+a2115*k[15]+a2116*k[16]+a2117*k[17]),rtmp); push!(k,copy(rtmp))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:Number,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern9}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 26 # Have not added the extra stages yet
    c17,a1701,a1708,a1709,a1710,a1711,a1712,a1713,a1714,a1715,c18,a1801,a1808,a1809,a1810,a1811,a1812,a1813,a1814,a1815,a1817,c19,a1901,a1908,a1909,a1910,a1911,a1912,a1913,a1914,a1915,a1917,a1918,c20,a2001,a2008,a2009,a2010,a2011,a2012,a2013,a2014,a2015,a2017,a2018,a2019,c21,a2101,a2108,a2109,a2110,a2111,a2112,a2113,a2114,a2115,a2117,a2118,a2119,a2120,c22,a2201,a2208,a2209,a2210,a2211,a2212,a2213,a2214,a2215,a2217,a2218,a2219,a2220,a2221,c23,a2301,a2308,a2309,a2310,a2311,a2312,a2313,a2314,a2315,a2317,a2318,a2319,a2320,a2321,c24,a2401,a2408,a2409,a2410,a2411,a2412,a2413,a2414,a2415,a2417,a2418,a2419,a2420,a2421,c25,a2501,a2508,a2509,a2510,a2511,a2512,a2513,a2514,a2515,a2517,a2518,a2519,a2520,a2521,c26,a2601,a2608,a2609,a2610,a2611,a2612,a2613,a2614,a2615,a2617,a2618,a2619,a2620,a2621 = Vern9Interp(uEltypeNoUnits)
    push!(k,f(t+c17*Δt,u+Δt*(a1701*k[1]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1713*k[13]+a1714*k[14]+a1715*k[15])))
    push!(k,f(t+c18*Δt,u+Δt*(a1801*k[1]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1813*k[13]+a1814*k[14]+a1815*k[15]+a1817*k[17])))
    push!(k,f(t+c19*Δt,u+Δt*(a1901*k[1]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1913*k[13]+a1914*k[14]+a1915*k[15]+a1917*k[17]+a1918*k[18])))
    push!(k,f(t+c20*Δt,u+Δt*(a2001*k[1]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2013*k[13]+a2014*k[14]+a2015*k[15]+a2017*k[17]+a2018*k[18]+a2019*k[19])))
    push!(k,f(t+c21*Δt,u+Δt*(a2101*k[1]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2113*k[13]+a2114*k[14]+a2115*k[15]+a2117*k[17]+a2118*k[18]+a2119*k[19]+a2120*k[20])))
    push!(k,f(t+c22*Δt,u+Δt*(a2201*k[1]+a2208*k[8]+a2209*k[9]+a2210*k[10]+a2211*k[11]+a2212*k[12]+a2213*k[13]+a2214*k[14]+a2215*k[15]+a2217*k[17]+a2218*k[18]+a2219*k[19]+a2220*k[20]+a2221*k[21])))
    push!(k,f(t+c23*Δt,u+Δt*(a2301*k[1]+a2308*k[8]+a2309*k[9]+a2310*k[10]+a2311*k[11]+a2312*k[12]+a2313*k[13]+a2314*k[14]+a2315*k[15]+a2317*k[17]+a2318*k[18]+a2319*k[19]+a2320*k[20]+a2321*k[21])))
    push!(k,f(t+c24*Δt,u+Δt*(a2401*k[1]+a2408*k[8]+a2409*k[9]+a2410*k[10]+a2411*k[11]+a2412*k[12]+a2413*k[13]+a2414*k[14]+a2415*k[15]+a2417*k[17]+a2418*k[18]+a2419*k[19]+a2420*k[20]+a2421*k[21])))
    push!(k,f(t+c25*Δt,u+Δt*(a2501*k[1]+a2508*k[8]+a2509*k[9]+a2510*k[10]+a2511*k[11]+a2512*k[12]+a2513*k[13]+a2514*k[14]+a2515*k[15]+a2517*k[17]+a2518*k[18]+a2519*k[19]+a2520*k[20]+a2521*k[21])))
    push!(k,f(t+c26*Δt,u+Δt*(a2601*k[1]+a2608*k[8]+a2609*k[9]+a2610*k[10]+a2611*k[11]+a2612*k[12]+a2613*k[13]+a2614*k[14]+a2615*k[15]+a2617*k[17]+a2618*k[18]+a2619*k[19]+a2620*k[20]+a2621*k[21])))
  end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern9}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 26 # Have not added the extra stages yet
    rtmp = rateType(size(k[1]))
    c17,a1701,a1708,a1709,a1710,a1711,a1712,a1713,a1714,a1715,c18,a1801,a1808,a1809,a1810,a1811,a1812,a1813,a1814,a1815,a1817,c19,a1901,a1908,a1909,a1910,a1911,a1912,a1913,a1914,a1915,a1917,a1918,c20,a2001,a2008,a2009,a2010,a2011,a2012,a2013,a2014,a2015,a2017,a2018,a2019,c21,a2101,a2108,a2109,a2110,a2111,a2112,a2113,a2114,a2115,a2117,a2118,a2119,a2120,c22,a2201,a2208,a2209,a2210,a2211,a2212,a2213,a2214,a2215,a2217,a2218,a2219,a2220,a2221,c23,a2301,a2308,a2309,a2310,a2311,a2312,a2313,a2314,a2315,a2317,a2318,a2319,a2320,a2321,c24,a2401,a2408,a2409,a2410,a2411,a2412,a2413,a2414,a2415,a2417,a2418,a2419,a2420,a2421,c25,a2501,a2508,a2509,a2510,a2511,a2512,a2513,a2514,a2515,a2517,a2518,a2519,a2520,a2521,c26,a2601,a2608,a2609,a2610,a2611,a2612,a2613,a2614,a2615,a2617,a2618,a2619,a2620,a2621 = Vern9Interp(uEltypeNoUnits)
    f(t+c17*Δt,u+Δt*(a1701*k[1]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1713*k[13]+a1714*k[14]+a1715*k[15]),rtmp); push!(k,copy(rtmp))
    f(t+c18*Δt,u+Δt*(a1801*k[1]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1813*k[13]+a1814*k[14]+a1815*k[15]+a1817*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c19*Δt,u+Δt*(a1901*k[1]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1913*k[13]+a1914*k[14]+a1915*k[15]+a1917*k[17]+a1918*k[18]),rtmp); push!(k,copy(rtmp))
    f(t+c20*Δt,u+Δt*(a2001*k[1]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2013*k[13]+a2014*k[14]+a2015*k[15]+a2017*k[17]+a2018*k[18]+a2019*k[19]),rtmp); push!(k,copy(rtmp))
    f(t+c21*Δt,u+Δt*(a2101*k[1]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2113*k[13]+a2114*k[14]+a2115*k[15]+a2117*k[17]+a2118*k[18]+a2119*k[19]+a2120*k[20]),rtmp); push!(k,copy(rtmp))
    f(t+c22*Δt,u+Δt*(a2201*k[1]+a2208*k[8]+a2209*k[9]+a2210*k[10]+a2211*k[11]+a2212*k[12]+a2213*k[13]+a2214*k[14]+a2215*k[15]+a2217*k[17]+a2218*k[18]+a2219*k[19]+a2220*k[20]+a2221*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c23*Δt,u+Δt*(a2301*k[1]+a2308*k[8]+a2309*k[9]+a2310*k[10]+a2311*k[11]+a2312*k[12]+a2313*k[13]+a2314*k[14]+a2315*k[15]+a2317*k[17]+a2318*k[18]+a2319*k[19]+a2320*k[20]+a2321*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c24*Δt,u+Δt*(a2401*k[1]+a2408*k[8]+a2409*k[9]+a2410*k[10]+a2411*k[11]+a2412*k[12]+a2413*k[13]+a2414*k[14]+a2415*k[15]+a2417*k[17]+a2418*k[18]+a2419*k[19]+a2420*k[20]+a2421*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c25*Δt,u+Δt*(a2501*k[1]+a2508*k[8]+a2509*k[9]+a2510*k[10]+a2511*k[11]+a2512*k[12]+a2513*k[13]+a2514*k[14]+a2515*k[15]+a2517*k[17]+a2518*k[18]+a2519*k[19]+a2520*k[20]+a2521*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c26*Δt,u+Δt*(a2601*k[1]+a2608*k[8]+a2609*k[9]+a2610*k[10]+a2611*k[11]+a2612*k[12]+a2613*k[13]+a2614*k[14]+a2615*k[15]+a2617*k[17]+a2618*k[18]+a2619*k[19]+a2620*k[20]+a2621*k[21]),rtmp); push!(k,copy(rtmp))
 end
  nothing
end

"""

"""
function ode_addsteps!{rateType<:AbstractArray,uEltypeNoUnits}(k,t,u,Δt,f,T::Type{Val{:Vern9Vectorized}},T2::Type{rateType},T3::Type{uEltypeNoUnits})
  if length(k) < 26 # Have not added the extra stages yet
    rtmp = rateType(size(k[1]))
    c17,a1701,a1708,a1709,a1710,a1711,a1712,a1713,a1714,a1715,c18,a1801,a1808,a1809,a1810,a1811,a1812,a1813,a1814,a1815,a1817,c19,a1901,a1908,a1909,a1910,a1911,a1912,a1913,a1914,a1915,a1917,a1918,c20,a2001,a2008,a2009,a2010,a2011,a2012,a2013,a2014,a2015,a2017,a2018,a2019,c21,a2101,a2108,a2109,a2110,a2111,a2112,a2113,a2114,a2115,a2117,a2118,a2119,a2120,c22,a2201,a2208,a2209,a2210,a2211,a2212,a2213,a2214,a2215,a2217,a2218,a2219,a2220,a2221,c23,a2301,a2308,a2309,a2310,a2311,a2312,a2313,a2314,a2315,a2317,a2318,a2319,a2320,a2321,c24,a2401,a2408,a2409,a2410,a2411,a2412,a2413,a2414,a2415,a2417,a2418,a2419,a2420,a2421,c25,a2501,a2508,a2509,a2510,a2511,a2512,a2513,a2514,a2515,a2517,a2518,a2519,a2520,a2521,c26,a2601,a2608,a2609,a2610,a2611,a2612,a2613,a2614,a2615,a2617,a2618,a2619,a2620,a2621 = Vern9Interp(uEltypeNoUnits)
    f(t+c17*Δt,u+Δt*(a1701*k[1]+a1708*k[8]+a1709*k[9]+a1710*k[10]+a1711*k[11]+a1712*k[12]+a1713*k[13]+a1714*k[14]+a1715*k[15]),rtmp); push!(k,copy(rtmp))
    f(t+c18*Δt,u+Δt*(a1801*k[1]+a1808*k[8]+a1809*k[9]+a1810*k[10]+a1811*k[11]+a1812*k[12]+a1813*k[13]+a1814*k[14]+a1815*k[15]+a1817*k[17]),rtmp); push!(k,copy(rtmp))
    f(t+c19*Δt,u+Δt*(a1901*k[1]+a1908*k[8]+a1909*k[9]+a1910*k[10]+a1911*k[11]+a1912*k[12]+a1913*k[13]+a1914*k[14]+a1915*k[15]+a1917*k[17]+a1918*k[18]),rtmp); push!(k,copy(rtmp))
    f(t+c20*Δt,u+Δt*(a2001*k[1]+a2008*k[8]+a2009*k[9]+a2010*k[10]+a2011*k[11]+a2012*k[12]+a2013*k[13]+a2014*k[14]+a2015*k[15]+a2017*k[17]+a2018*k[18]+a2019*k[19]),rtmp); push!(k,copy(rtmp))
    f(t+c21*Δt,u+Δt*(a2101*k[1]+a2108*k[8]+a2109*k[9]+a2110*k[10]+a2111*k[11]+a2112*k[12]+a2113*k[13]+a2114*k[14]+a2115*k[15]+a2117*k[17]+a2118*k[18]+a2119*k[19]+a2120*k[20]),rtmp); push!(k,copy(rtmp))
    f(t+c22*Δt,u+Δt*(a2201*k[1]+a2208*k[8]+a2209*k[9]+a2210*k[10]+a2211*k[11]+a2212*k[12]+a2213*k[13]+a2214*k[14]+a2215*k[15]+a2217*k[17]+a2218*k[18]+a2219*k[19]+a2220*k[20]+a2221*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c23*Δt,u+Δt*(a2301*k[1]+a2308*k[8]+a2309*k[9]+a2310*k[10]+a2311*k[11]+a2312*k[12]+a2313*k[13]+a2314*k[14]+a2315*k[15]+a2317*k[17]+a2318*k[18]+a2319*k[19]+a2320*k[20]+a2321*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c24*Δt,u+Δt*(a2401*k[1]+a2408*k[8]+a2409*k[9]+a2410*k[10]+a2411*k[11]+a2412*k[12]+a2413*k[13]+a2414*k[14]+a2415*k[15]+a2417*k[17]+a2418*k[18]+a2419*k[19]+a2420*k[20]+a2421*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c25*Δt,u+Δt*(a2501*k[1]+a2508*k[8]+a2509*k[9]+a2510*k[10]+a2511*k[11]+a2512*k[12]+a2513*k[13]+a2514*k[14]+a2515*k[15]+a2517*k[17]+a2518*k[18]+a2519*k[19]+a2520*k[20]+a2521*k[21]),rtmp); push!(k,copy(rtmp))
    f(t+c26*Δt,u+Δt*(a2601*k[1]+a2608*k[8]+a2609*k[9]+a2610*k[10]+a2611*k[11]+a2612*k[12]+a2613*k[13]+a2614*k[14]+a2615*k[15]+a2617*k[17]+a2618*k[18]+a2619*k[19]+a2620*k[20]+a2621*k[21]),rtmp); push!(k,copy(rtmp))
 end
  nothing
end
