// Copyright 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

#include <cstdio>
#define TACC double

template <typename T, Int K, Int V>
__global__ void
dDeconvolution_KMxKN_forwardA(T *inFeatures, T *outFeatures, T *w, Int *rules,
			      Int nHot, Int input_nPlanes, Int input_stride,
			      Int output_nPlanes, Int output_stride) {
  // nHot must be a multiple of K!!

  // Input x Weight -> Output
  // blockDim=(K,K/V,1), gridDim=(nBlocks,N,1) Volkov-blocks
  // K is a multiple of V,

  // nHot x KM -> nHot x KN - parallel over N,nHot - loop over M

  Int M = input_nPlanes / K;
  // N = gridDim.y == output_nPlanes/K
  Int n = blockIdx.y;
  outFeatures += n * K;
  w += n * K;

  TACC O[V];
  __shared__ T W[K][K];
  __shared__ T I[K][K];
  Int R0[V];
  Int R1[V];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int m = 0; m < M; m++) {
// Read w
#pragma unroll
    for (int v = 0; v < V; v++)
      W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
#pragma unroll
      for (int v = 0; v < V; v++) {
	R1[v] = rules[2 * (s + ty[v])];
	R0[v] = rules[2 * (s + ty[v]) + 1];
      }
      __syncthreads();

// Read input, reset O[]
#pragma unroll
      for (int v = 0; v < V; v++) {
	I[ty[v]][tx] = inFeatures[R0[v] * input_stride + tx];
	O[v] = 0;
      }
      __syncthreads();

#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
	for (int v = 0; v < V; v++)
	  O[v] += I[ty[v]][k] * W[k][tx];

#pragma unroll
      for (int v = 0; v < V; v++)
	O[v] += outFeatures[R1[v] * output_stride + tx];
#pragma unroll
      for (int v = 0; v < V; v++)
	outFeatures[R1[v] * output_stride + tx] = O[v];
      __syncthreads();
    }
    w += K * output_nPlanes;
    inFeatures += K;
  }
}


template <typename T, Int K, Int V>
__global__ void
dDeconvolution_incre_KMxKN_forwardA(T *inFeatures, T *outFeatures, T *w, Int *rules,
			      Int nHot, Int input_nPlanes, Int input_stride,
			      Int output_nPlanes, Int output_stride, T *pre_input_feats, Int *pre_exist_input, Int *pre_exist_out) {
  // nHot must be a multiple of K!!

  // Input x Weight -> Output
  // blockDim=(K,K/V,1), gridDim=(nBlocks,N,1) Volkov-blocks
  // K is a multiple of V,

  // nHot x KM -> nHot x KN - parallel over N,nHot - loop over M

  Int M = input_nPlanes / K;
  // N = gridDim.y == output_nPlanes/K
  Int n = blockIdx.y;
  outFeatures += n * K;
  w += n * K;

  TACC O[V];
  __shared__ T W[K][K];
  __shared__ T I[K][K];

  Int R0[V];
  Int R1[V];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int m = 0; m < M; m++) {
// Read w
#pragma unroll
    for (int v = 0; v < V; v++)
      W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
#pragma unroll
      for (int v = 0; v < V; v++) {
        R1[v] = rules[2 * (s + ty[v])];
        R0[v] = rules[2 * (s + ty[v]) + 1];
      }
      __syncthreads();

// Read input, reset O[]
#pragma unroll
      for (int v = 0; v < V; v++) {
        I[ty[v]][tx] = inFeatures[R0[v] * input_stride + tx];
        if (pre_exist_input[R0[v]] >= 0 && pre_exist_out[R1[v]] < 0) 
          I[ty[v]][tx] += pre_input_feats[pre_exist_input[R0[v]] * input_stride + tx];
        O[v] = 0;
      }
      __syncthreads();

#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
        for (int v = 0; v < V; v++)
          O[v] += I[ty[v]][k] * W[k][tx];

#pragma unroll
      for (int v = 0; v < V; v++)
	      O[v] += outFeatures[R1[v] * output_stride + tx];
#pragma unroll
      for (int v = 0; v < V; v++)
	      outFeatures[R1[v] * output_stride + tx] = O[v];
      __syncthreads();
    }
    w += K * output_nPlanes;
    inFeatures += K;
    pre_input_feats += K;
  }
}




template <typename T, Int K, Int V>
__global__ void
dDeconvolution_KMxKN_forwardB(T *inFeatures, T *outFeatures, T *w, Int *rules,
			      Int nHot, Int input_nPlanes, Int input_stride,
			      Int output_nPlanes, Int output_stride) {
  // Input x Weight -> Output
  // blockDim=(K,K/V,1), gridDim=(nBlocks,N,1) Volkov-blocks
  // K is a multiple of V,

  // nHot x KM -> nHot x KN - parallel over N,nHot - loop over M

  Int M = input_nPlanes / K;
  // N = gridDim.y == output_nPlanes/K
  Int n = blockIdx.y;
  outFeatures += n * K;
  w += n * K;

  TACC O[V];
  __shared__ T W[K][K];
  __shared__ T I[K][K];
  Int R0[V];
  Int R1[V];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int m = 0; m < M; m++) {
// Read w
#pragma unroll
    for (int v = 0; v < V; v++)
      W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (s + ty[v] < nHot) {
	  R1[v] = rules[2 * (s + ty[v])];
	  R0[v] = rules[2 * (s + ty[v]) + 1];
	}
      }
      __syncthreads();

// Read input, reset O[]
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (s + ty[v] < nHot)
	  I[ty[v]][tx] = inFeatures[R0[v] * input_stride + tx];
	O[v] = 0;
      }
      __syncthreads();

#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
	for (int v = 0; v < V; v++)
	  O[v] += I[ty[v]][k] * W[k][tx];

#pragma unroll
      for (int v = 0; v < V; v++)
	if (s + ty[v] < nHot)
	  O[v] += outFeatures[R1[v] * output_stride + tx];
#pragma unroll
      for (int v = 0; v < V; v++)
	if (s + ty[v] < nHot)
	  outFeatures[R1[v] * output_stride + tx] = O[v];
      __syncthreads();
    }
    w += K * output_nPlanes;
    inFeatures += K;
  }
}


template <typename T, Int K, Int V>
__global__ void
dDeconvolution_incre_KMxKN_forwardB(T *inFeatures, T *outFeatures, T *w, Int *rules,
			      Int nHot, Int input_nPlanes, Int input_stride,
			      Int output_nPlanes, Int output_stride , T *pre_input_feats, Int *pre_exist_input, Int *pre_exist_out) {
  // Input x Weight -> Output
  // blockDim=(K,K/V,1), gridDim=(nBlocks,N,1) Volkov-blocks
  // K is a multiple of V,

  // nHot x KM -> nHot x KN - parallel over N,nHot - loop over M

  Int M = input_nPlanes / K;
  // N = gridDim.y == output_nPlanes/K
  Int n = blockIdx.y;
  outFeatures += n * K;
  w += n * K;

  TACC O[V];
  __shared__ T W[K][K];
  __shared__ T I[K][K];
  Int R0[V];
  Int R1[V];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int m = 0; m < M; m++) {
// Read w
#pragma unroll
    for (int v = 0; v < V; v++)
      W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
#pragma unroll
      for (int v = 0; v < V; v++) {
        if (s + ty[v] < nHot) {
          R1[v] = rules[2 * (s + ty[v])];
          R0[v] = rules[2 * (s + ty[v]) + 1];
        }
      }
      __syncthreads();

// Read input, reset O[]
#pragma unroll
      for (int v = 0; v < V; v++) {
        if (s + ty[v] < nHot) {
          I[ty[v]][tx] = inFeatures[R0[v] * input_stride + tx];
          if (pre_exist_input[R0[v]] >= 0 && pre_exist_out[R1[v]] < 0) 
            I[ty[v]][tx] += pre_input_feats[pre_exist_input[R0[v]] * input_stride + tx];
        }
        O[v] = 0;
      }
      __syncthreads();

#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
        for (int v = 0; v < V; v++)
          O[v] += I[ty[v]][k] * W[k][tx];

#pragma unroll
      for (int v = 0; v < V; v++)
	      if (s + ty[v] < nHot)
          O[v] += outFeatures[R1[v] * output_stride + tx];
#pragma unroll
      for (int v = 0; v < V; v++)
        if (s + ty[v] < nHot)
          outFeatures[R1[v] * output_stride + tx] = O[v];
      __syncthreads();
    }
    w += K * output_nPlanes;
    inFeatures += K;
    pre_input_feats += K;
  }
}




#define FOO(T, K, V)                                                           \
  {                                                                            \
    if (input_nPlanes % K == 0 and output_nPlanes % K == 0) {                  \
      Int o = (nHot / K) * K;                                                  \
      if (o >= K)                                                              \
	dDeconvolution_KMxKN_forwardA<                                         \
	    T, K, V><<<dim3(std::min(o / K, (Int)512), output_nPlanes / K),    \
		       dim3(K, K / V)>>>(inFeatures, outFeatures, w, rules, o, \
					 input_nPlanes, input_stride,          \
					 output_nPlanes, output_stride);       \
      if (nHot > o)                                                            \
	dDeconvolution_KMxKN_forwardB<                                         \
	    T, K, V><<<dim3(1, output_nPlanes / K), dim3(K, K / V)>>>(         \
	    inFeatures, outFeatures, w, rules + 2 * o, nHot - o,               \
	    input_nPlanes, input_stride, output_nPlanes, output_stride);       \
      return;                                                                  \
    }                                                                          \
  }

template <typename T>
void dDeconvolution_forward(T *inFeatures, T *outFeatures, T *w, Int *rules,
			    Int nHot, Int input_nPlanes, Int input_stride,
			    Int output_nPlanes, Int output_stride) {
  FOO(T, 64, 16)
  FOO(T, 32, 8)
  FOO(T, 16, 4)
  FOO(T, 8, 2)
  assert(false);
}

#define INC_FOO(T, K, V)                                                       \
  {                                                                            \
    if (input_nPlanes % K == 0 and output_nPlanes % K == 0) {                  \
      Int o = (nHot / K) * K;                                                  \
      if (o >= K)                                                              \
        dDeconvolution_incre_KMxKN_forwardA<T, K, V>                           \
            <<<dim3(std::min(o / K, (Int)512), output_nPlanes / K),            \
               dim3(K, K / V)>>>(inFeatures, outFeatures, w, rules, o,         \
                                 input_nPlanes, input_stride, output_nPlanes,  \
                                 output_stride, pre_input_feats,               \
                                 pre_exist_input, pre_exist_out);              \
      if (nHot > o)                                                            \
        dDeconvolution_incre_KMxKN_forwardB<T, K, V>                           \
            <<<dim3(1, output_nPlanes / K), dim3(K, K / V)>>>(                 \
                inFeatures, outFeatures, w, rules + 2 * o, nHot - o,           \
                input_nPlanes, input_stride, output_nPlanes, output_stride,    \
                pre_input_feats, pre_exist_input, pre_exist_out);              \
      return;                                                                  \
    }                                                                          \
  }

template <typename T>
void dDeconvolution_incre_forward(T *inFeatures, T *outFeatures, T *w, Int *rules,
			    Int nHot, Int input_nPlanes, Int input_stride,
			    Int output_nPlanes, Int output_stride, T *pre_input_feats, Int *pre_exist_input, Int *pre_exist_out) {
  INC_FOO(T, 64, 16)
  INC_FOO(T, 32, 8)
  INC_FOO(T, 16, 4)
  INC_FOO(T, 8, 2)
  assert(false);
}



template <>
void dDeconvolution_forward<double>(double *inFeatures, double *outFeatures,
				    double *w, Int *rules, Int nHot,
				    Int input_nPlanes, Int input_stride,
				    Int output_nPlanes, Int output_stride) {
  FOO(double, 32, 8)
  FOO(double, 16, 4)
  FOO(double, 8, 2)
  assert(false);
}
#undef FOO

// dOutput x W^T -> dInput and
// Input^T x dOutput -> dW
// blockDim=(K,K/V,1), gridDim=(nBlocks,M,1)
template <typename T, Int K, Int V>
__global__ void dDeconvolution_KMxKN_backward_dW_A(
    T *inFeatures, T *dInFeatures, T *dOutFeatures, T *w, T *dw, Int *rules,
    Int nHot, Int input_nPlanes, Int input_stride, Int output_nPlanes,
    Int output_stride) {
  // M = gridDim.y == input_nPlanes / K
  Int N = output_nPlanes / K;
  Int m = blockIdx.y;
  inFeatures += m * K;
  dInFeatures += m * K;
  w += m * K * output_nPlanes;
  dw += m * K * output_nPlanes;

  TACC dI[V];
  TACC dW[V];
  __shared__ T I[K][K];
  __shared__ T dO[K][K];
  __shared__ T W[K][K];
  Int R0[V];
  Int R1[V];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int n = 0; n < N; n++) {
// Read w, reset dW
#pragma unroll
    for (int v = 0; v < V; v++) {
      W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];
      dW[v] = 0;
    }

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
#pragma unroll
      for (int v = 0; v < V; v++) {
	R1[v] = rules[2 * (s + ty[v])];
	R0[v] = rules[2 * (s + ty[v]) + 1];
	dI[v] = 0;
      }
      __syncthreads();
// Read input and dOutput
#pragma unroll
      for (int v = 0; v < V; v++) {
	I[ty[v]][tx] = inFeatures[R0[v] * input_stride + tx];
	dO[ty[v]][tx] = dOutFeatures[R1[v] * output_stride + tx];
      }
      __syncthreads();
#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
	for (int v = 0; v < V; v++) {
	  dI[v] += dO[ty[v]][k] * W[tx][k];
	  dW[v] += I[k][ty[v]] * dO[k][tx];
	}
#pragma unroll
      for (int v = 0; v < V; v++)
	dI[v] += dInFeatures[R0[v] * input_stride + tx];
#pragma unroll
      for (int v = 0; v < V; v++)
	dInFeatures[R0[v] * input_stride + tx] = dI[v];
      __syncthreads();
    }
#pragma unroll
    for (int v = 0; v < V; v++)
      atomicAdd(&dw[ty[v] * output_nPlanes + tx], dW[v]);
    w += K;
    dw += K;
    dOutFeatures += K;
  }
}

// dOutput x W^T -> dInput and
// Input^T x dOutput -> dW
// blockDim=(K,K/V,1), gridDim=(nBlocks,M,1)
template <typename T, Int K, Int V>
__global__ void dDeconvolution_KMxKN_backward_dW_B(
    T *inFeatures, T *dInFeatures, T *dOutFeatures, T *w, T *dw, Int *rules,
    Int nHot, Int input_nPlanes, Int input_stride, Int output_nPlanes,
    Int output_stride) {
  // M = gridDim.y == input_nPlanes / K
  Int N = output_nPlanes / K;
  Int m = blockIdx.y;
  inFeatures += m * K;
  dInFeatures += m * K;
  w += m * K * output_nPlanes;
  dw += m * K * output_nPlanes;

  TACC dI[V];
  TACC dW[V];
  __shared__ T I[K][K];
  __shared__ T dO[K][K];
  __shared__ T W[K][K];
  Int R0[V];
  Int R1[V];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int n = 0; n < N; n++) {
// Read w, reset dW
#pragma unroll
    for (int v = 0; v < V; v++) {
      W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];
      dW[v] = 0;
    }

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (s + ty[v] < nHot) {
	  R1[v] = rules[2 * (s + ty[v])];
	  R0[v] = rules[2 * (s + ty[v]) + 1];
	}
	dI[v] = 0;
      }
      __syncthreads();
// Read input and dOutput
#pragma unroll
      for (int v = 0; v < V; v++)
	if (s + ty[v] < nHot) {
	  I[ty[v]][tx] = inFeatures[R0[v] * input_stride + tx];
	  dO[ty[v]][tx] = dOutFeatures[R1[v] * output_stride + tx];
	} else {
	  I[ty[v]][tx] = 0;
	  dO[ty[v]][tx] = 0;
	}
      __syncthreads();
#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
	for (int v = 0; v < V; v++) {
	  dI[v] += dO[ty[v]][k] * W[tx][k];
	  dW[v] += I[k][ty[v]] * dO[k][tx];
	}
#pragma unroll
      for (int v = 0; v < V; v++)
	if (s + ty[v] < nHot)
	  dI[v] += dInFeatures[R0[v] * input_stride + tx];
#pragma unroll
      for (int v = 0; v < V; v++)
	if (s + ty[v] < nHot)
	  dInFeatures[R0[v] * input_stride + tx] = dI[v];
      __syncthreads();
    }
#pragma unroll
    for (int v = 0; v < V; v++)
      atomicAdd(&dw[ty[v] * output_nPlanes + tx], dW[v]);
    w += K;
    dw += K;
    dOutFeatures += K;
  }
}

#define FOO(T, K, V)                                                           \
  {                                                                            \
    if (input_nPlanes % K == 0 and output_nPlanes % K == 0) {                  \
      Int o = (nHot / K) * K;                                                  \
      if (o >= K)                                                              \
	dDeconvolution_KMxKN_backward_dW_A<                                    \
	    T, K, V><<<dim3(std::min(o / K, (Int)512), input_nPlanes / K),     \
		       dim3(K, K / V)>>>(                                      \
	    inFeatures, dInFeatures, dOutFeatures, w, dw, rules, o,            \
	    input_nPlanes, input_stride, output_nPlanes, output_stride);       \
      if (nHot > o)                                                            \
	dDeconvolution_KMxKN_backward_dW_B<                                    \
	    T, K, V><<<dim3(1, input_nPlanes / K), dim3(K, K / V)>>>(          \
	    inFeatures, dInFeatures, dOutFeatures, w, dw, rules + 2 * o,       \
	    nHot - o, input_nPlanes, input_stride, output_nPlanes,             \
	    output_stride);                                                    \
      return;                                                                  \
    }                                                                          \
  }

template <typename T>
void dDeconvolution_backward_dW(T *inFeatures, T *dInFeatures, T *dOutFeatures,
				T *w, T *dw, Int *rules, Int nHot,
				Int input_nPlanes, Int input_stride,
				Int output_nPlanes, Int output_stride) {
  FOO(T, 32, 8)
  FOO(T, 16, 4)
  FOO(T, 8, 2)
  assert(false);
}
#undef FOO

template <typename T, Int K, Int V>
__global__ void
dDeconvolution_KMxKN_forward2(T *inFeatures, T *outFeatures, T *w, Int *rules,
			      Int nHot, Int input_nPlanes, Int input_stride,
			      Int output_nPlanes, Int output_stride) {
  // Input x Weight -> Output
  // blockDim=(K,K/V,1), gridDim=(nBlocks,N,1) Volkov-blocks
  // K is a multiple of V,

  // nHot x input_nplanes<=KM -> nHot x output_nPlanes<=KN
  // - parallel over N,nHot - loop over M

  Int M = (input_nPlanes + K - 1) / K;
  // N = gridDim.y ~ output_nPlanes/K
  Int n = blockIdx.y;
  outFeatures += n * K;
  w += n * K;
  Int KO = min(K, output_nPlanes - K * n);

  TACC O[V];
  __shared__ T W[K][K];
  __shared__ T I[K][K];
  __shared__ Int R[K * 2];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int m = 0; m < M; m++) {
    Int KI = min(K, input_nPlanes - K * m);

// Read w
#pragma unroll
    for (int v = 0; v < V; v++)
      if (ty[v] < KI and tx < KO)
	W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
// Read rules for K input/output pairs
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (ty[v] < 2) {
	  int q = ty[v] * K + tx;
	  if (s + q / 2 < nHot)
	    R[q] = rules[2 * s + q];
	}
      }
      __syncthreads();

// Read input, reset O[]
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (tx < KI and s + ty[v] < nHot)
	  I[ty[v]][tx] = inFeatures[R[2 * ty[v] + 1] * input_stride + tx];
	O[v] = 0;
      }
      __syncthreads();

#pragma unroll
      for (int k = 0; k < KI; k++)
#pragma unroll
	for (int v = 0; v < V; v++)
	  O[v] += I[ty[v]][k] * W[k][tx];
      __syncthreads();

#pragma unroll
      for (int v = 0; v < V; v++)
	if (tx < KO and s + ty[v] < nHot)
	  outFeatures[R[2 * ty[v]] * output_stride + tx] += O[v];
      __syncthreads();
    }
    w += K * output_nPlanes;
    inFeatures += K;
  }
}

// dOutput x W^T -> dInput and
// Input^T x dOutput -> dW
// blockDim=(K,K/V,1), gridDim=(nBlocks,M,1)
template <typename T, Int K, Int V>
__global__ void
dDeconvolution_KMxKN_backward_dW2(T *inFeatures, T *dInFeatures,
				  T *dOutFeatures, T *w, T *dw, Int *rules,
				  Int nHot, Int input_nPlanes, Int input_stride,
				  Int output_nPlanes, Int output_stride) {
  // M = gridDim.y == input_nPlanes / K
  Int N = (output_nPlanes + K - 1) / K;
  Int m = blockIdx.y;
  inFeatures += m * K;
  dInFeatures += m * K;
  w += m * K * output_nPlanes;
  dw += m * K * output_nPlanes;
  Int KI = min(K, input_nPlanes - K * m);

  TACC dI[V];
  TACC dW[V];
  __shared__ T I[K][K];
  __shared__ T dO[K][K];
  __shared__ T W[K][K];
  __shared__ Int R[K * 2];
  const int tx = threadIdx.x;
  int ty[V];
#pragma unroll
  for (int v = 0; v < V; v++)
    ty[v] = threadIdx.y + v * (K / V);

  for (int n = 0; n < N; n++) {
    Int KO = min(K, output_nPlanes - K * n);

// Read w, reset dW
#pragma unroll
    for (int v = 0; v < V; v++) {
      if (ty[v] < KI and tx < KO)
	W[ty[v]][tx] = w[ty[v] * output_nPlanes + tx];
      dW[v] = 0;
    }

    for (Int s = blockIdx.x * K; s < nHot; s += K * gridDim.x) {
// Read rules for K input/output pairs, reset dI[]
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (ty[v] < 2) {
	  int q = ty[v] * K + tx;
	  if (s + q / 2 < nHot)
	    R[q] = rules[2 * s + q];
	}
	dI[v] = 0;
      }
      __syncthreads();
// Read input and dOutput
#pragma unroll
      for (int v = 0; v < V; v++) {
	if (tx < KI and s + ty[v] < nHot)
	  I[ty[v]][tx] = inFeatures[R[2 * ty[v] + 1] * input_stride + tx];
	else
	  I[ty[v]][tx] = 0;
	if (tx < KO and s + ty[v] < nHot)
	  dO[ty[v]][tx] = dOutFeatures[R[2 * ty[v]] * output_stride + tx];
	else
	  dO[ty[v]][tx] = 0;
      }
      __syncthreads();
#pragma unroll
      for (int k = 0; k < KO; k++)
#pragma unroll
	for (int v = 0; v < V; v++)
	  dI[v] += dO[ty[v]][k] * W[tx][k];
#pragma unroll
      for (int k = 0; k < K; k++)
#pragma unroll
	for (int v = 0; v < V; v++)
	  dW[v] += I[k][ty[v]] * dO[k][tx];
      __syncthreads();
#pragma unroll
      for (int v = 0; v < V; v++)
	if (tx < KI and s + ty[v] < nHot)
	  dInFeatures[R[2 * ty[v] + 1] * input_stride + tx] += dI[v];
      __syncthreads();
    }
#pragma unroll
    for (int v = 0; v < V; v++)
      if (ty[v] < KI and tx < KO)
	atomicAdd(&dw[ty[v] * output_nPlanes + tx], dW[v]);
    w += K;
    dw += K;
    dOutFeatures += K;
  }
}

template <typename T>
double dDeconvolution_forward2(T *inFeatures, T *outFeatures, T *w,
			       RuleBook _rules, Int input_nPlanes,
			       Int input_stride, Int output_nPlanes,
			       Int output_stride) {
  Int c = input_nPlanes * output_nPlanes;
  double flops = 0;
  if (input_nPlanes % 8 != 0 or output_nPlanes % 8 != 0) {
    const int K = 16;
    const int V = 4;
    RULEBOOKITERATOR(
	(dDeconvolution_KMxKN_forward2<
	    T, K,
	    V><<<dim3(128, (output_nPlanes + K - 1) / K), dim3(K, K / V)>>>(
	    inFeatures, outFeatures, w, rbB, nHotB, input_nPlanes, input_stride,
	    output_nPlanes, output_stride));
	, w += c; flops += nHotB * c;)
  } else {
    RULEBOOKITERATOR(dDeconvolution_forward(inFeatures, outFeatures, w, rbB,
					    nHotB, input_nPlanes, input_stride,
					    output_nPlanes, output_stride);
		     , w += c; flops += nHotB * c;)
  }
  return flops;
}


template <typename T>
double dDeconvolution_incre_forward2(T *inFeatures, T *outFeatures, T *w,
			       RuleBook _rules, Int input_nPlanes,
			       Int input_stride, Int output_nPlanes,
			       Int output_stride, T * pre_input_feats, Int *pre_exist_input, Int *pre_exist_out) {
  Int c = input_nPlanes * output_nPlanes;
  double flops = 0;
  if (input_nPlanes % 8 != 0 or output_nPlanes % 8 != 0) {
    const int K = 16;
    const int V = 4;
    printf("entering unimplemented area, dDeconvolution_incre_forward2");
    RULEBOOKITERATOR(
	(dDeconvolution_KMxKN_forward2<
	    T, K,
	    V><<<dim3(128, (output_nPlanes + K - 1) / K), dim3(K, K / V)>>>(
	    inFeatures, outFeatures, w, rbB, nHotB, input_nPlanes, input_stride,
	    output_nPlanes, output_stride));
	, w += c; flops += nHotB * c;)
  } else {
    RULEBOOKITERATOR(dDeconvolution_incre_forward(inFeatures, outFeatures, w, rbB,
					    nHotB, input_nPlanes, input_stride,
					    output_nPlanes, output_stride, pre_input_feats, pre_exist_input, pre_exist_out);
		     , w += c; flops += nHotB * c;)
  }
  return flops;
}


template <typename T>
void dDeconvolution_backward_dW2(T *inFeatures, T *dInFeatures, T *dOutFeatures,
				 T *w, T *dw, RuleBook _rules,
				 Int input_nPlanes, Int input_stride,
				 Int output_nPlanes, Int output_stride) {
  Int c = input_nPlanes * output_nPlanes;
  if (input_nPlanes % 8 != 0 or output_nPlanes % 8 != 0) {
    const int K = 16;
    const int V = 4;
    RULEBOOKITERATOR(
	(dDeconvolution_KMxKN_backward_dW2<
	    T, K,
	    V><<<dim3(128, (input_nPlanes + K - 1) / K), dim3(K, K / V)>>>(
	    inFeatures, dInFeatures, dOutFeatures, w, dw, rbB, nHotB,
	    input_nPlanes, input_stride, output_nPlanes, output_stride));
	, w += c; dw += c;)
  } else {
    RULEBOOKITERATOR(dDeconvolution_backward_dW(inFeatures, dInFeatures,
						dOutFeatures, w, dw, rbB, nHotB,
						input_nPlanes, input_stride,
						output_nPlanes, output_stride);
		     , w += c; dw += c;)
  }
}

#undef TACC