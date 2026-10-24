// vector_add.ispc

export void vector_add_ispc(uniform const float a[], 
                            uniform const float b[], 
                            uniform float c[], 
                            uniform int count) 
{
    // The ISPC compiler maps this foreach loop to underlying 
    // AVX2/AVX-512 SIMD vector instructions automatically.
    foreach (i = 0 ... count) {
        c[i] = a[i] + b[i];
    }
}