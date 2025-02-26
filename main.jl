using LinearAlgebra
using DataFrames
using CSV
using Plots
using SparseArrays

lines = DataFrame(CSV.File("Clase_2/lines.csv"))
nodes = DataFrame(CSV.File("Clase_2/nodes.csv"))

s = only(nodes[nodes.TYPE .== 3, "NUMBER"])

# Se calcula la matriz Bbus reducida sin nodo slack

function B_bus(lines,nodes)
    """
    Entradas:   lines: DataFrames
                nodes : DataFrames
    Salida :    Bbus : matriz
    """
    num_nodes = nrow(nodes)
    num_lines = nrow(lines)
    Bbus = zeros(num_nodes, num_nodes)

    for k = 1:num_lines
        # Nodo de envío
        n1 = lines.FROM[k]
        # Nodo de recibo
        n2 = lines.TO[k]
        # Susceptancia
        BL = 1/(lines.X[k])
        Bbus[n1,n1] += BL        # Dentro de la diagonal
        Bbus[n1,n2] -= BL        # Fuera de la diagonal
        Bbus[n2,n1] -= BL        # Fuera de la diagonal
        Bbus[n2,n2] += BL        # Dentro de la diagonal
    end
    # Identificando el nodo slack
    s = nodes[nodes.TYPE .== 3, "NUMBER"]
    Bbus = Bbus[setdiff(1:num_nodes, s), setdiff(1:num_nodes, s)] 
    return Bbus
end

function calculo_de_α(Bbus, lines, nodes)

    """
    Entradas:   lines: DataFrames
                nodes : DataFrames
                Bbus : matriz
    Salida :    α : matriz
    """

    num_nodes = nrow(nodes)
    num_lines = nrow(lines)

    # Es mejor usar una única asignación con try-catch
    W_ini = try
        inv(Bbus)
    catch
        pinv(Bbus)
    end

    r, n = size(W_ini)

    W = zeros(r + 1, n + 1)

    # Hallando el nodo slack
    s = only(nodes[nodes.TYPE .== 3, "NUMBER"])

    # Añadiendo las filas y columnas del nodo slack    
    W[1:s-1, 1:s-1] = W_ini[1:s-1, 1:s-1]  # Parte superior izquierda
    W[1:s-1, s+1:end] = W_ini[1:s-1, s:end]  # Parte superior derecha
    W[s+1:end, 1:s-1] = W_ini[s:end, 1:s-1]  # Parte inferior izquierda
    W[s+1:end, s+1:end] = W_ini[s:end, s:end]  # Parte inferior derecha

    # Preallocate matrix
    alpha = zeros(num_lines, num_nodes)
    
    for i in 1:num_lines
        k = lines.FROM[i]
        m = lines.TO[i]
        for j in 1:num_nodes
            alpha[i,j] = 1/lines.X[i] * (W[k,j] - W[m,j])
        end
    end
    
    return alpha
end
B = B_bus(lines, nodes)

calculo_de_α(B, lines, nodes)


function calculo_de_δ(Bbus, lines, nodes)

    """
    Entradas:   lines: DataFrames
                nodes : DataFrames
                Bbus : matriz
    Salida :    δ : matriz
    """

    num_nodes = nrow(nodes)
    num_lines = nrow(lines)

    # Es mejor usar una única asignación con try-catch
    W_ini = try
        inv(Bbus)
    catch
        pinv(Bbus)
    end

    r, n = size(W_ini)

    W = zeros(r + 1, n + 1)

    # Hallando el nodo slack
    s = only(nodes[nodes.TYPE .== 3, "NUMBER"])

    # Añadiendo las filas y columnas del nodo slack    
    W[1:s-1, 1:s-1] = W_ini[1:s-1, 1:s-1]  # Parte superior izquierda
    W[1:s-1, s+1:end] = W_ini[1:s-1, s:end]  # Parte superior derecha
    W[s+1:end, 1:s-1] = W_ini[s:end, 1:s-1]  # Parte inferior izquierda
    W[s+1:end, s+1:end] = W_ini[s:end, s:end]  # Parte inferior derecha

    delta = zeros(num_nodes, num_lines)

    for i in 1:num_lines
        k = lines.FROM[i]
        m = lines.TO[i]
        for j in 1:num_nodes
            delta[j,i] = (lines.X[i]*(W[j,k] - W[j,m]))/(lines.X[i] - (W[k,k] + W[m,m] - 2*W[m,k]))
            # delta[i,j] = (lines.X[i]*(W[k,j] - W[m,j]))/(lines.X[i] + (W[k,k] + W[m,m] - 2*W[m,k]))
        end
    end

    return delta

end

delta = calculo_de_δ(B, lines, nodes)

function calculo_de_β(Bbus,delta, lines, nodes)

    """
    Entradas:   lines: DataFrames
                nodes : DataFrames
                Bbus : matriz
    Salida :    β : matriz
    """

    num_nodes = nrow(nodes)
    num_lines = nrow(lines)

    # Es mejor usar una única asignación con try-catch
    W_ini = try
        inv(Bbus)
    catch
        pinv(Bbus)
    end

    r, n = size(W_ini)

    W = zeros(r + 1, n + 1)

    # Hallando el nodo slack
    s = only(nodes[nodes.TYPE .== 3, "NUMBER"])

    # Añadiendo las filas y columnas del nodo slack    
    W[1:s-1, 1:s-1] = W_ini[1:s-1, 1:s-1]  # Parte superior izquierda
    W[1:s-1, s+1:end] = W_ini[1:s-1, s:end]  # Parte superior derecha
    W[s+1:end, 1:s-1] = W_ini[s:end, 1:s-1]  # Parte inferior izquierda
    W[s+1:end, s+1:end] = W_ini[s:end, s:end]  # Parte inferior derecha

    beta = zeros(num_lines, num_lines)

    for l in 1:num_lines
        n = lines.FROM[l]
        m = lines.TO[l]
        for k in 1:num_lines
            i = lines.FROM[k]
            j = lines.TO[k]
            if l != k
                beta[l,k] = (lines.X[k]/lines.X[l])*((W[i,n] - W[j,n] - W[i,m] + W[j,m])/(lines.X[k] - W[i,i] - W[j,j] + 2*W[i,j]))
            end
        end
    end

    return beta
end

calculo_de_β(B, delta, lines, nodes)