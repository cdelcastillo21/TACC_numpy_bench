import numpy as np

class NumpyBenchmarks:
    def setup(self):
        self.arr = np.random.rand(1000, 1000)

    def time_matrix_multiply(self):
        np.dot(self.arr, self.arr)

    def time_eigenvalues(self):
        np.linalg.eigvals(self.arr)
