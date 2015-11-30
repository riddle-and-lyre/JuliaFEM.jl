# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

# Elasticity problems

abstract ElasticityProblem <: AbstractProblem

function get_unknown_field_name{P<:ElasticityProblem}(::Type{P})
    return "displacement"
end

function get_unknown_field_type{P<:ElasticityProblem}(::Type{P})
    return Vector{Float64}
end

function ElasticityProblem(dim::Int=3, elements=[])
    return Problem{PlaneStressElasticityProblem}(dim, elements)
end

abstract PlaneStressElasticityProblem <: ElasticityProblem

function PlaneStressElasticityProblem(dim::Int=2, elements=[])
    return Problem{PlaneStressElasticityProblem}(dim, elements)
end

""" Elasticity equations.

Formulation
-----------

Field equation is:
∂u/∂t = ∇⋅f - b

Weak form is: find u∈U such that ∀v in V

    δW := ∫ρ₀∂²u/∂t²⋅δu dV₀ + ∫S:δE dV₀ - ∫b₀⋅δu dV₀ - ∫t₀⋅δu dA₀ = 0

where

    ρ₀ = density
    b₀ = displacement load
    t₀ = displacement traction

References
----------

https://en.wikipedia.org/wiki/Linear_elasticity
https://en.wikipedia.org/wiki/Finite_strain_theory
https://en.wikipedia.org/wiki/Stress_measures
https://en.wikipedia.org/wiki/Mooney%E2%80%93Rivlin_solid
https://en.wikipedia.org/wiki/Strain_energy_density_function
https://en.wikipedia.org/wiki/Plane_stress
https://en.wikipedia.org/wiki/Hooke's_law

"""
function get_residual_vector{P<:ElasticityProblem}(problem::Problem{P}, element::Element, ip::IntegrationPoint, time::Number; variation=nothing)

    basis = element(ip, time)

    u = element("displacement", ip, time, variation)

    r = zeros(Float64, problem.dim, length(element))

    # internal forces
    if haskey(element, "youngs modulus") && haskey(element, "poissons ratio")
        dbasis = element(ip, time, Val{:grad})
        gradu = element("displacement", ip, time, Val{:grad}, variation)
        F = I + gradu # deformation gradient

        young = element("youngs modulus", ip, time)
        poisson = element("poissons ratio", ip, time)
        mu = young/(2*(1+poisson))
        lambda = young*poisson/((1+poisson)*(1-2*poisson))
        if P == PlaneStressElasticityProblem
            lambda = 2*lambda*mu/(lambda + 2*mu)  # <- correction for 2d problems
        end
        E = 1/2*(F'*F - I)  # strain
        S = lambda*trace(E)*I + 2*mu*E

        J = det(element, ip, time)
        T = J^-1*F*S*F'
        #ip["cauchy stress"] = T
        ip["gl strain"] = E

        r += F*S*dbasis
    end

    # external forces - volume load
    if haskey(element, "displacement load")
        b = element("displacement load", ip, time)
        r -= b*basis
    end

    # external forces - surface traction force
    if haskey(element, "displacement traction force")
        T = element("displacement traction force", ip, time)
        r -= T*basis
    end

    return vec(r)
end
