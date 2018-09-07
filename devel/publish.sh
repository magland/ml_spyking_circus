rm -rf build/ dist/ ml_spyking_circus.egg-info/
python3 setup.py sdist bdist_wheel
twine upload dist/*
