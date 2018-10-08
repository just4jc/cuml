#include <gtest/gtest.h>
#include "linalg/add.h"
#include "random/rng.h"
#include "test_utils.h"


namespace MLCommon {
namespace LinAlg {


template <typename Type>
__global__ void naiveAddElemKernel(Type* out, const Type* in1, const Type* in2,
                               int len) {
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
    if(idx < len) {
        out[idx] = in1[idx] + in2[idx];
    }
}

template <typename Type>
void naiveAddElem(Type* out, const Type* in1, const Type* in2, int len) {
    static const int TPB = 64;
    int nblks = ceildiv(len, TPB);
    naiveAddElemKernel<Type><<<nblks,TPB>>>(out, in1, in2, len);
    CUDA_CHECK(cudaPeekAtLastError());
}


template <typename T>
struct AddInputs {
    T tolerance;
    int len;
    unsigned long long int seed;
};

template <typename T>
::std::ostream& operator<<(::std::ostream& os, const AddInputs<T>& dims) {
    return os;
}

template <typename T>
class AddTest: public ::testing::TestWithParam<AddInputs<T> > {
protected:
    void SetUp() override {
        params = ::testing::TestWithParam<AddInputs<T>>::GetParam();
        Random::Rng<T> r(params.seed);
        int len = params.len;
        allocate(in1, len);
        allocate(in2, len);
        allocate(out_ref, len);
        allocate(out, len);
        r.uniform(in1, len, T(-1.0), T(1.0));
        r.uniform(in2, len, T(-1.0), T(1.0));
        naiveAddElem(out_ref, in1, in2, len);
        add(out, in1, in2, len);
        add(in1, in1, in2, len);
    }

    void TearDown() override {
        CUDA_CHECK(cudaFree(in1));
        CUDA_CHECK(cudaFree(in2));
        CUDA_CHECK(cudaFree(out_ref));
        CUDA_CHECK(cudaFree(out));
    }

protected:
    AddInputs<T> params;
    T *in1, *in2, *out_ref, *out;
};

const std::vector<AddInputs<float> > inputsf2 = {
    {0.000001f, 1024*1024, 1234ULL}
};

const std::vector<AddInputs<double> > inputsd2 = {
    {0.00000001, 1024*1024, 1234ULL}
};

typedef AddTest<float> AddTestF;
TEST_P(AddTestF, Result) {
    ASSERT_TRUE(devArrMatch(out_ref, out, params.len,
                            CompareApprox<float>(params.tolerance)));

    ASSERT_TRUE(devArrMatch(out_ref, in1, params.len,
                            CompareApprox<float>(params.tolerance)));
}

typedef AddTest<double> AddTestD;
TEST_P(AddTestD, Result){
    ASSERT_TRUE(devArrMatch(out_ref, out, params.len,
                            CompareApprox<double>(params.tolerance)));

    ASSERT_TRUE(devArrMatch(out_ref, in1, params.len,
                            CompareApprox<double>(params.tolerance)));
}

INSTANTIATE_TEST_CASE_P(AddTests, AddTestF,
                        ::testing::ValuesIn(inputsf2));

INSTANTIATE_TEST_CASE_P(AddTests, AddTestD,
                        ::testing::ValuesIn(inputsd2));

} // end namespace LinAlg
} // end namespace MLCommon